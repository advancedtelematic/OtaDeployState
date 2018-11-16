import StateMachine
import Kube
import PromiseKit
import Foundation
import func PromiseKit.firstly

public final class AuthPlus {
    public var machine:StateMachine<AuthPlus>!
    public var authPlusApi = AuthPlusApi()
    public let kube = Kube()
    public var attempts = 4
    public var clientsConfigPath: String = "/usr/local/etc/ota-deploy-state/clients.json"
    public let initFilePath = "/usr/local/opt/ota-deploy-state/auth-plus-init"

    public init() {
        machine = StateMachine(initialState: .ready, delegate: self)
    }

    public enum State {
        case unknown
        case unavailable
        case uninitialised
        case initialised
        case needsManualIntervention
        case checkingClients
        case creatingClients([ClientState.State])
        case ready
    }

    public enum AuthPlusError: Error {
        case invalidJsonConfig(file: String)
        case initTokenLost
    }

    public func requiredClients() throws -> [AuthPlusApi.ClientMetadata] {
        // TODO: switch to use Optional
        do {
            let filePath = URL(fileURLWithPath: self.clientsConfigPath)
            let data = try Data(contentsOf: filePath)
            return try JSONDecoder().decode([AuthPlusApi.ClientMetadata].self, from: data)
        } catch let error {
            print(error)
            throw AuthPlusError.invalidJsonConfig(file: clientsConfigPath)
        }
    }

    public func createAndSave(client: AuthPlusApi.ClientMetadata) -> Promise<Kube.Secret<AuthPlusApi.Client>> {
        return Promise<Kube.Secret<AuthPlusApi.Client>> { seal in
            firstly {
                self.authPlusApi.create(client: client) as Promise<AuthPlusApi.Client>
            }.then { client in
                self.kube.updateSecret(name: client.clientName, body: client) as Promise<Kube.Secret<AuthPlusApi.Client>>
            }.done { client in
                seal.fulfill(client)
            }.catch { error in
                seal.reject(error)
            }
        }
    }

    public func createAndUpdate(client: AuthPlusApi.ClientMetadata) -> Promise<Kube.Secret<AuthPlusApi.Client>> {
        return Promise<Kube.Secret<AuthPlusApi.Client>> { seal in
            firstly {
                self.authPlusApi.create(client: client) as Promise<AuthPlusApi.Client>
                }.then { client in
                    self.kube.updateSecret(name: client.clientName, body: client) as Promise<Kube.Secret<AuthPlusApi.Client>>
                }.done { client in
                    seal.fulfill(client)
                }.catch { error in
                    seal.reject(error)
            }
        }
    }

    func getInitCredentials() -> Promise<AuthPlusApi.Client> {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: self.initFilePath)
        if fm.fileExists(atPath: self.initFilePath) {
            print("Found auth plus init credentials file")
            return Promise<AuthPlusApi.Client> { seal in
                do {
                    let initText = try String(contentsOf: url, encoding: .utf8)
                    print("printing file contents")
                    let initCreds = try JSONDecoder().decode(AuthPlusApi.Client.self, from: initText.data(using: .utf8)!)
                    seal.fulfill(initCreds)
                }
                catch {
                    print("failed to decode auth plus credentials")
                    seal.reject(error)
                }
            }
        } else {
            print("Auth plus file not found, initialising server")
            return authPlusApi.initialiseServer() as Promise<AuthPlusApi.Client>
        }
    }
}

extension AuthPlus : StateMachineDelegateProtocol{
    public typealias StateType = State

    public func shouldTransition(from: StateType, to: StateType) -> Should<StateType> {
        switch (from, to){
        case (.ready, .unknown),
             (.unknown, .unavailable),
             (.unavailable, .uninitialised),
             (.unavailable, .initialised):
            return .Continue
            // case (.initialised, .uninitialised):
        //    return .Redirect(.Stop)
        default:
            return .Continue
        }
    }

    public func didTransition(from: StateType, to: StateType) {
        switch to{
        case .unknown:
            print("Auth plus status unknown")
            print("Checking initialiased status")
            let fm = FileManager.default
            if fm.fileExists(atPath: self.initFilePath) {
                print("init credentials file found on disk")
                self.machine.state = .uninitialised
            } else {
                let isInit = authPlusApi.fetchInitialised()
                isInit.done { initStatus in
                    if initStatus.initialized {
                        self.machine.state = .initialised
                    } else {
                        self.machine.state = .uninitialised
                    }
                    }.catch{ error in
                        print("Error while checking initialiased status")
                        print(error)
                        self.machine.state = .unavailable
                }
            }
        case .unavailable:
            print("Auth plus unavailable")
        case .uninitialised:
            print("Auth plus uninitialised")
            print("Initialising auth plus")
            let fileUrl = URL(fileURLWithPath: self.initFilePath)
            firstly {
                // TODO: Check if secret is already in k8s
                self.getInitCredentials()
            }.then { initClient -> Promise<Kube.Secret<AuthPlusApi.Client>> in
                print("Auth plus init credentials received")
                print("Saving init credentials to kubernetes")
                let text = try JSONEncoder().encode(initClient)
                //writing
                do {
                    try text.write(to: fileUrl)
                } catch {
                    print("Failed to write vault init credentials to disk, \(error)")
                }
                return self.kube.updateSecret(name: "auth-plus-init", body: initClient) as Promise<Kube.Secret<AuthPlusApi.Client>>
            }.done { client in
                print("saved init client to kubernetes")
                self.machine.state = .initialised
                print("removing init credentials file")
                let fileManager = FileManager.default
                do {
                    try fileManager.removeItem(atPath: fileUrl.path)
                }
                catch let error as NSError {
                    print("Could not remove file: \(error)")
                }
            }.catch { error in
                print("Error while initialising")
                print(error)
                self.machine.state = .needsManualIntervention
            }
        case .initialised:
            print("Auth plus initialised")
            print("Configuring auth plus credentials")
            firstly {
                kube.fetchSecret(name: "auth-plus-init") as Promise<Kube.Secret<AuthPlusApi.Client>>
            }.then { client -> Promise<AuthPlusApi.AuthPlusToken> in
                self.authPlusApi.adminClient = client.data
                return self.authPlusApi.createToken(for: client.data) as Promise<AuthPlusApi.AuthPlusToken>
            }.done { token in
                print("Created bearer token")
                self.authPlusApi.token = token
                self.machine.state = .checkingClients
            }.catch { error in
                print("Error getting auth credentials")
                print(error)
                self.machine.state = .needsManualIntervention
            }
        case .creatingClients(let states):
            print("creating clients")
            let creating = states.map { (state) -> Promise<Kube.Secret<AuthPlusApi.Client>>? in
                switch state {
                case .created(let clientMd):
                    print("already created: \(clientMd.clientName)")
                    return nil
                case .doesNotExist(let clientMd):
                    print("\(clientMd.clientName) doesn't exist. Creating.")
                    return self.createAndSave(client: clientMd)
                case .inK8sOnly(let clientMd):
                    print("\(clientMd.clientName) only exists in k8s. Recreating.")
                    return self.createAndUpdate(client: clientMd)
                }
            }.compactMap { $0 }
            when(fulfilled: creating).done { kubeClients in
                print("all created sucessfully")
                self.machine.state = .ready
            }.catch { error in
                print("error creating some clients")
                print(error)
                if self.attempts > 0 {
                    self.attempts -= 1
                    self.machine.state = .checkingClients
                } else {
                    self.machine.state = .needsManualIntervention
                }
            }
        case .needsManualIntervention:
             print("Something's very wrong. Needs manual intervention.")
        case .ready:
            print("Auth plus initialised and clients created. Ready.")

        case .checkingClients:
            let reqClients = try! self.requiredClients()
            let clientStatuses = reqClients.map({ cmd -> Promise<ClientState.State> in
                let clientState = ClientState(kube: kube, authPlusApi: authPlusApi)
                return clientState.checkState(clientMetadata: cmd)
            })

            when(fulfilled: clientStatuses).done { states in
                self.machine.state = .creatingClients(states)
            }.catch {error in
                print("Error checking clients status")
                print(error)
                self.machine.state = .needsManualIntervention
            }
        }
    }
}
