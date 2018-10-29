import StateMachine
import Kube

public final class AuthPlus {
    public var machine:StateMachine<AuthPlus>!
    public let authPlusApi = AuthPlusApi()

    public init() {
        machine = StateMachine(initialState: .ready, delegate: self)
    }

    public enum State {
        case unknown
        case unavailable
        case uninitialised
        case initialised
        case init_token_lost
        case no_clients
        case ready
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
            let isInit = authPlusApi.fetchInitialised()
            isInit.done { initStatus in
                print(initStatus)
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
        case .unavailable:
            print("Auth plus unavailable")
        case .uninitialised:
            print("Auth plus uninitialised")
            print("Initialising auth plus")
            let initServer = authPlusApi.initialiseServer()
            initServer.done { initClient in
                print("Initialised auth plus")
                print(initClient)
                print("Saving init credentials to kubernetes")
                // TODO: save to k8s
            }.catch { error in
                print("Error while initialising")
                print(error)
            }
        case .initialised:
            print("Auth plus initialised")
            // TODO: check for clients in k8s
            // TODO: check that clients in k8s are in auth plus
        case .no_clients:
            print("Auth plus initialised but no clients")
            // TODO: create clients
        case .ready:
            print("Auth plus initialised and clients created")
            // TODO: create clients
        case .init_token_lost:
            print("No tokens in k8s after auth plus initialiased")
        }
    }
}

