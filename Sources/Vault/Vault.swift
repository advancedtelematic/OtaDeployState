import Foundation
import StateMachine
import Kube
import PromiseKit
import SwiftyBeaver

let log = SwiftyBeaver.self

public final class Vault {
    public var machine:StateMachine<Vault>!
    public var vaultApi = VaultApi()
    public let kube = Kube()
    public var attempts = 4
    public let config: VaultConfig
    public let initFilePath = "/usr/local/opt/ota-deploy-state/vault-init"

    public init(config: VaultConfig) {
        self.config = config
        machine = StateMachine(initialState: .ready, delegate: self)
        self.vaultApi.baseUrl = config.url
    }

    public enum State {
        case unknown
        case unavailable
        case uninitialised
        case initialised
        case sealed
        case unsealed
        case checkingSealStatus
        case creatingMounts([VaultApi.MountState])
        case checkingMounts
        case creatingPolicies
        case checkingTokens
        case creatingTokens([TokenState.State])
        case needsManualIntervention
        case ready
    }

    public enum VaultError: Error {
        case invalidJsonConfig(file: String)
        case ranOutForKeys
        case unsealError(Error)
    }

    func unsealLoop(keysBase64: [String], index: Int = 0, seal: Resolver<VaultApi.UnsealStatus>) {
        if index >  keysBase64.count - 1 {
            seal.reject(VaultError.ranOutForKeys)
        }
        firstly {
            vaultApi.unsealPut(key: VaultApi.UnsealPayload(key: keysBase64[index]))
        }.done { status in
            log.verbose("Vault unseal status: \(status)")
            if status.sealed {
                self.unsealLoop(keysBase64: keysBase64, index: index + 1, seal: seal)
            } else {
                seal.fulfill(status)
            }
        }.catch { error in
            log.error("Vault unseal error: \(error)")
            seal.reject(error)
        }
    }

    func doUnseal(keysBase64: [String]) -> Promise<VaultApi.UnsealStatus> {
        return Promise<VaultApi.UnsealStatus> { seal in
            self.unsealLoop(keysBase64: keysBase64, seal: seal)
        }
    }

    func getInitCredentials() -> Promise<VaultApi.InitCredentials> {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: self.initFilePath)
        if fm.fileExists(atPath: self.initFilePath) {
            return Promise<VaultApi.InitCredentials> { seal in
                do {
                    let initText = try String(contentsOf: url, encoding: .utf8)
                    let initCreds = try JSONDecoder().decode(VaultApi.InitCredentials.self, from: initText.data(using: .utf8)!)
                    seal.fulfill(initCreds)
                }
                catch {
                    seal.reject(error)
                }
            }
        } else {
            return vaultApi.initializeServer() as Promise<VaultApi.InitCredentials>
        }
    }

    func createAndSaveToken(token: VaultConfig.Token) -> Promise<Kube.Secret<VaultApi.TokenK8s>> {
        return Promise<Kube.Secret<VaultApi.TokenK8s>> { seal in
            let req = VaultApi.TokenCreateRequest(period: token.period, policies: token.policies, displayName: token.displayName)
            self.vaultApi.createToken(tokenCreateRequest: req)
                .then({ tokenResponse -> Promise<Kube.Secret<VaultApi.TokenK8s>> in
                self.kube.updateSecret(name: token.displayName, body: VaultApi.TokenK8s(token: tokenResponse.auth.clientToken))
                }).done({ secret in
                    seal.fulfill(secret)
                }).catch({ error in
                    seal.reject(error)
                })
        }
    }

    func recreateToken(token: VaultConfig.Token) -> Promise<Kube.Secret<VaultApi.TokenK8s>> {
        return Promise<Kube.Secret<VaultApi.TokenK8s>> { seal in
            firstly {
                self.kube.fetchSecret(name: token.displayName) as Promise<Kube.Secret<VaultApi.TokenK8s>>
                }.then({ tokenK8s -> Promise<(VaultApi.TokenCreateResponse, Kube.Secret<VaultApi.TokenK8s>)> in
                    let req = VaultApi.TokenCreateRequest(period: token.period, policies: token.policies, displayName: token.displayName, id: tokenK8s.data.vaultToken)
                    return self.vaultApi.createToken(tokenCreateRequest: req).map({ ($0, tokenK8s) })
                }).done({ tokenCreateResponse, tokenk8s in
                    seal.fulfill(tokenk8s)
                }).catch({ error in
                    seal.reject(error)
                })
        }
    }
}

extension Vault : StateMachineDelegateProtocol{
    public typealias StateType = State

    public func shouldTransition(from: StateType, to: StateType) -> Should<StateType> {
        switch (from, to){
        default:
            return .Continue
        }
    }

    public func didTransition(from: StateType, to: StateType) {
        switch to{
        case .unknown:
            log.verbose("Status unknown.")
            let fm = FileManager.default
            if fm.fileExists(atPath: self.initFilePath) {
                log.info("Init credentials file found on disk.")
                self.machine.state = .uninitialised
            } else {
                vaultApi.fetchInitialised().done { initStatus in
                    log.verbose("Vault init status: \(initStatus.initialized)")
                    if initStatus.initialized {
                        self.machine.state = .initialised
                    } else {
                        self.machine.state = .uninitialised
                    }
                    }.catch { error in
                        log.error("Error during get to init status: \(error)")
                        self.machine.state = .unavailable
                }
            }
        case .unavailable:
            log.error("Unavailable.")
        case .uninitialised:
            log.info("Uninitialised.")
            log.info("Initialising.")
            let fileUrl = URL(fileURLWithPath: self.initFilePath)
            firstly {
                self.getInitCredentials() as Promise<VaultApi.InitCredentials>
            }.then { initCreds -> Promise<Kube.Secret<Kube.JsonBlob<VaultApi.InitCredentials>>> in
                log.verbose("Vault successfully initialised.")
                log.verbose("Saving init credentials to k8s.")
                let text = try JSONEncoder().encode(initCreds)
                //writing
                do {
                    try text.write(to: fileUrl)
                    try FileManager.default.setAttributes([FileAttributeKey.posixPermissions : UInt16(0o600)], ofItemAtPath: fileUrl.path)
                } catch {
                    log.error("Failed to write vault init credentials to disk: \(error)")
                }
                return self.kube.updateSecretJsonBlob(name: "ota-vault-init", body: initCreds)
            }.done { saved in
                log.verbose("Credentials saved to k8s.")
                self.machine.state = .initialised
                log.verbose("Removing init credentials file.")
                let fileManager = FileManager.default
                do {
                    try fileManager.removeItem(atPath: fileUrl.path)
                }
                catch let error as NSError {
                    log.error("Could not remove file: \(error)")
                }
            }.catch { error in
                log.error("Error during initialisation: \(error)")
                self.machine.state = .unavailable
            }
        case .initialised:
            log.info("Initialised.")
            log.verbose("Fetching credentials.")
            firstly {
                self.kube.fetchSecret(name: "ota-vault-init") as Promise<Kube.Secret<Kube.JsonBlob<VaultApi.InitCredentials>>>
            }.done { (secretCreds) in
                self.vaultApi.initCreds = secretCreds.data.blob
                self.machine.state = .checkingSealStatus
            }.catch { error in
                log.error("Error while fetching secrets: \(error)")
                self.machine.state = .needsManualIntervention
            }
        case .creatingPolicies:
            log.info("Creating policies.")

            let policies = config.policies.map { policy -> VaultApi.PolicyBody in
                // TODO: Fix `try!`
                try! VaultApi.PolicyBody(name: policy.name, policyPath: policy.pathToPolicy)
            }
            when(fulfilled: policies.map { policy -> Promise<Void> in
                vaultApi.createPolicy(policyBody: policy)
            }).done {
                log.info("Policies created.")
                self.machine.state = .checkingMounts
            }.catch { error in
                log.error("Error creating policies: \(error)")
                self.machine.state = .needsManualIntervention
            }
        case .checkingMounts:
            log.verbose("Checking policies.")
            let mounts = config.mounts.map { mount -> VaultApi.MountBody in
                VaultApi.MountBody(path: mount.path, type: mount.type)
            }

            let states = mounts.map { mountBody -> Promise<VaultApi.MountState> in
                self.vaultApi.checkMountState(mount: mountBody)
            }

            when(fulfilled: states).done { mountStates in
                self.machine.state = .creatingMounts(mountStates)
            }.catch { error in
                log.error("Error checking mount states: \(error)")
                self.machine.state = .unknown
            }

        case .creatingMounts(let states):
            log.verbose("Creating mounts.")

            let creating = states.map { mountStates -> Promise<VaultApi.Mount>? in
                switch mountStates {
                case .exists(let mb):
                    log.verbose("Already exists: \(mb.path)")
                    return .none
                case .doesNotExist(let mb):
                    return self.vaultApi.createMount(mountBody: mb)
                }
            }.compactMap({$0})
            when(fulfilled: creating).done { mounts in
                log.verbose("Mounts created.")
                self.machine.state = .checkingTokens
            }.catch { error in
                log.error("Error creating mounts: \(error)")
                self.machine.state = .unknown
            }
        case .ready:
            log.info("Vault initialised, policies and mounts created. Ready.")
        case .needsManualIntervention:
            log.error("Something's very wrong. Needs manual intervention.")
        case .checkingSealStatus:
            log.verbose("Checking sealed status.")
            firstly {
                vaultApi.fetchSealStatus()
            }.done { status in
                if status.sealed {
                    self.machine.state = .sealed
                } else {
                    self.machine.state = .unsealed
                }
            }.catch { error in
                log.error("Error checking seal status.")
                self.machine.state = .unknown
            }
        case .sealed:
            log.info("Vault is sealed. Unsealing.")
            // TODO add unseal attempts
            switch self.vaultApi.initCreds {
            case .some(let creds):
                firstly {
                    self.doUnseal(keysBase64: creds.keysBase64)
                }.done { unsealStatus in
                    if unsealStatus.sealed {
                        self.machine.state = .sealed
                    } else {
                        self.machine.state = .unsealed
                    }
                }.catch { error in
                    log.error("Error unsealing vault.")
                    self.machine.state = .needsManualIntervention
                }
            case .none:
                log.error("Vault initialisation credentials not found.")
                self.machine.state = .unknown
            }
        case .unsealed:
            log.info("Unsealed.")
            self.machine.state = .creatingPolicies
        case .checkingTokens:
            log.verbose("Checking tokens.")
            let states = config.tokens.map { token -> Promise<TokenState.State> in
                return TokenState.init(kube: self.kube, vaultApi: self.vaultApi).checkTokenState(token: token)
            }
            when(fulfilled: states).done { states in
                self.machine.state = .creatingTokens(states)
            }.catch { error in
                log.error("Error checking states: \(error)")
                self.machine.state = .unknown
            }
        case .creatingTokens(let states):
            log.info("Creating tokens.")

            let creating = states.map { state -> Promise<Kube.Secret<VaultApi.TokenK8s>>? in
                switch state {
                case .exists(let token):
                    log.verbose("\(token.displayName) already exists.")
                    return .none
                case .doesNotExist(let token):
                    log.verbose("\(token.displayName) does not exist, creating.")
                    return self.createAndSaveToken(token: token)
                case .expiring(let token):
                    log.verbose("\(token.displayName) is expiring, recreating.")
                    return self.recreateToken(token: token)
                case .ink8sOnly(let token):
                    log.verbose("\(token.displayName) is only in k8s and not vault, recreating.")
                    return self.recreateToken(token: token)
                }
            }.compactMap({ $0 })


            when(fulfilled: creating).done { createResponses in
                log.verbose("Tokens created.")
                self.machine.state = .ready
            }.catch { error in
                log.error("Error creating token: \(error)")
                self.machine.state = .needsManualIntervention
            }
        }
    }
}
