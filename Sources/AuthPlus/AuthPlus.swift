import StateMachine

public final class AuthPlus {
    public var machine:StateMachine<AuthPlus>!
    public let authPlusApi = AuthPlusApi()

    public init() {
        machine = StateMachine(initialState: .s_unavailable, delegate: self)
    }

    public enum State {
        case s_unavailable
        case s_uninitialised
        case s_initialised
        case init_token_lost
        case no_clients
        case clients_created
    }
}

extension AuthPlus : StateMachineDelegateProtocol{
    public typealias StateType = State

    public func shouldTransition(from: StateType, to: StateType) -> Should<StateType> {
        switch (from, to){
        case (.s_unavailable, .s_uninitialised), (.s_unavailable, .s_initialised):
            return .Continue
            // case (.initialised, .uninitialised):
        //    return .Redirect(.Stop)
        default:
            return .Abort
        }
    }

    public func didTransition(from: StateType, to: StateType) {
        switch to{
        case .s_unavailable:
            print("Auth plus unavailable")
        case .s_uninitialised:
            print("Auth plus uninitialised")
        case .s_initialised:
            print("Auth plus initialised")
        case .no_clients:
            print("Auth plus initialised but no clients")
        case .clients_created:
            print("Auth plus initialised and clients created")
        case .init_token_lost:
            print("No tokens in k8s after auth plus initialiased")
        }
    }
}

