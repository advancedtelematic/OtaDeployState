import Foundation
import PromiseKit
import SwiftyRequest
import StateMachine

public func unpacker<A: Codable>(prom: Promise<A>) -> A {
    do {
        print("waiting")
        return try prom.wait()
    } catch {
        fatalError()
    }
}

public final class AuthPlus {
    public var machine:StateMachine<AuthPlus>!

    public init() {
        machine = StateMachine(initialState: .s_unavailable, delegate: self)
    }

    public enum AuthPlusState {
        case s_unavailable
        case s_uninitialised
        case s_initialised
        case no_clients
        case clients_created
    }
}


public class AuthPlusApi {
    public init() {}
    public func isInitialised() -> Promise<InitStatus>  {
        return Promise<InitStatus> { seal in
            let request = RestRequest(method: .get, url: "http://localhost:8000/init")
            request.responseObject { (response: RestResponse<InitStatus>) in
                switch response.result {
                case .success(let initStatus):
                    seal.fulfill(initStatus)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    public enum InitialisedStatus {
        case initialised(Initialized)
        case uninitialised
    }

    public struct Initialized: Codable {
    }

    public struct InitStatus: Codable {
        public init() {}
        var initialized: Initialized?

        public var isInitialised: InitialisedStatus {
            if let s = initialized {
                return InitialisedStatus.initialised(s)
            } else {
                return InitialisedStatus.uninitialised
            }
        }

        enum CodingKeys: String, CodingKey {
            case initialized = "initialized"
        }
    }
}

extension AuthPlus : StateMachineDelegateProtocol{
    public typealias StateType = AuthPlusState

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
        }
    }
}

