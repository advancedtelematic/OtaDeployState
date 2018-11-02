import Foundation
import StateMachine
import Kube
import PromiseKit

public final class Vault {
    public var machine:StateMachine<Vault>!
    public var vaultApi = VaultApi()
    public let kube = Kube()
    public var attempts = 4
    public let config: VaultConfig

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
            print(status)
            if status.sealed {
                self.unsealLoop(keysBase64: keysBase64, index: index + 1, seal: seal)
            } else {
                seal.fulfill(status)
            }
        }.catch { error in
            print(error)
            seal.reject(error)
        }
    }

    func doUnseal(keysBase64: [String]) -> Promise<VaultApi.UnsealStatus> {
        return Promise<VaultApi.UnsealStatus> { seal in
            self.unsealLoop(keysBase64: keysBase64, seal: seal)
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
            print("Vault status unknown")
            vaultApi.fetchInitialised().done { initStatus in
                print(initStatus)
                if initStatus.initialized {
                    self.machine.state = .initialised
                } else {
                    self.machine.state = .uninitialised
                }
            }.catch { error in
                print(error)
                self.machine.state = .unavailable
            }
        case .unavailable:
            print("Vault unavailable")
        case .uninitialised:
            print("Vault uninitialised")
            print("Initialising vault")
            firstly {
                vaultApi.initializeServer() as Promise<VaultApi.InitCredentials>
            }.then { initCreds -> Promise<Kube.Secret<Kube.JsonBlob<VaultApi.InitCredentials>>> in
                print("Vault successfully initialised")
                print("Saving init credentials to k8s")
                return self.kube.updateSecretJsonBlob(name: "ota-vault-init", body: initCreds)
            }.done { saved in
                print("Credentials saved to k8s")
                self.machine.state = .initialised
            }.catch { error in
                print(error)
            }
        case .initialised:
            print("Vault initialised")
            print("Fetching credentials")
            firstly {
                self.kube.fetchSecret(name: "ota-vault-init") as Promise<Kube.Secret<Kube.JsonBlob<VaultApi.InitCredentials>>>
            }.done { (secretCreds) in
                self.vaultApi.initCreds = secretCreds.data.blob
                self.machine.state = .checkingSealStatus
            }.catch { error in
                print("error while fetching vault secrets")
                self.machine.state = .needsManualIntervention
            }
        case .creatingPolicies:
            print("creating policies")

            let policies = config.policies.map { policy -> VaultApi.PolicyBody in
                // TODO: Fix `try!`
                try! VaultApi.PolicyBody(name: policy.name, policyPath: policy.pathToPolicy)
            }
            when(fulfilled: policies.map { policy -> Promise<Void> in
                vaultApi.createPolicy(policyBody: policy)
            }).done {
                print("policies created")
                self.machine.state = .checkingMounts
            }.catch { error in
                print(error)
                self.machine.state = .needsManualIntervention
            }
        case .checkingMounts:
            let mounts = config.mounts.map { mount -> VaultApi.MountBody in
                VaultApi.MountBody(path: mount.path, type: mount.type)
            }

            let states = mounts.map { mountBody -> Promise<VaultApi.MountState> in
                self.vaultApi.checkMountState(mount: mountBody)
            }

            when(fulfilled: states).done { mountStates in
                self.machine.state = .creatingMounts(mountStates)
            }.catch { error in
                print("error checking mount states")
                self.machine.state = .unknown
            }

        case .creatingMounts(let states):
            print("creating mounts")

            let creating = states.map { mountStates -> Promise<VaultApi.Mount>? in
                switch mountStates {
                case .exists(let mb):
                    print("already exists: \(mb.path)")
                    return nil
                case .doesNotExist(let mb):
                    return self.vaultApi.createMount(mountBody: mb)
                }
            }.compactMap({$0})
            when(fulfilled: creating).done { mounts in
                print("mounts created")
                self.machine.state = .checkingTokens
            }.catch { error in
                print("error creating mounts")
                self.machine.state = .unknown
            }
        case .ready:
            print("Vault initialised, policies and mounts created. Ready.")
        case .needsManualIntervention:
            print("Something's very wrong. Needs manual intervention.")
        case .checkingSealStatus:
            print("Checking sealed status")
            firstly {
                vaultApi.fetchSealStatus()
            }.done { status in
                if status.sealed {
                    self.machine.state = .sealed
                } else {
                    self.machine.state = .unsealed
                }
            }.catch { error in
                print("error checking seal status")
                self.machine.state = .unknown
            }
        case .sealed:
            print("Vault is sealed. Unsealing")
            // TODO add unseal attempts
            switch self.vaultApi.initCreds {
            case .some(let creds):
                firstly {
                    self.doUnseal(keysBase64: creds.keysBase64)
                }.done { unsealStatus in
                    if unsealStatus.sealed {
                        self.machine.state = .sealed
                    } else {
                        self.machine.state = .creatingPolicies
                    }
                }.catch { error in
                    print("error unsealing vault")
                    self.machine.state = .needsManualIntervention
                }
            case .none:
                self.machine.state = .unknown
            }
        case .unsealed:
            print("Unsealed.")
            self.machine.state = .creatingPolicies
        case .checkingTokens:
            print("checking tokens")
            let states = config.tokens.map { token -> Promise<TokenState.State> in
                return TokenState.init(kube: self.kube, vaultApi: self.vaultApi).checkTokenState(token: token)
            }
            when(fulfilled: states).done { states in
                self.machine.state = .creatingTokens(states)
            }.catch { error in
                print("error checking states")
                print(error)
                self.machine.state = .unknown
            }
        case .creatingTokens(let states):
            print("creating tokens")

            let creating = states.map { state -> Promise<Kube.Secret<VaultApi.TokenK8s>>? in
                switch state {
                case .exists(let token):
                    print("\(token.displayName) already exists")
                    return .none
                case .doesNotExist(let token):
                    print("\(token.displayName) does not exist, creating")
                    return self.createAndSaveToken(token: token)
                case .expiring(let token):
                    print("\(token.displayName) is expiring, recreating")
                    return self.recreateToken(token: token)
                case .ink8sOnly(let token):
                    print("\(token.displayName) is only in k8s and not vault, recreating")
                    return self.recreateToken(token: token)
                }
            }.compactMap({ $0 })


            when(fulfilled: creating).done { createResponses in
                print("tokens created")
                self.machine.state = .ready
            }.catch { error in
                print("error creating token")
                print(error)
                self.machine.state = .needsManualIntervention
            }
        }
    }
}
