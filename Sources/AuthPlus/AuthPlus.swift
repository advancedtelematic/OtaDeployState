import Foundation
import PromiseKit
import SwiftyRequest
import enum SwiftyRequest.Result
import StateMachine
import MiniNetwork

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

public struct Client: Codable {
    let clientId: String
    let clientName: String
    let clientSecret: String

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case clientName = "client_name"
        case clientSecret = "client_secret"
    }
}

public class AuthPlusApi {
    public let baseUrl = "http://ota-auth-plus"
    public init() {}
    public func fetchInitialised() -> Promise<InitialisedStatus>  {
        return asyncGet(url: "\(baseUrl)/init") as Promise<InitialisedStatus>
    }

    public struct InitialisedStatus: Decodable {
        public var initialized: Bool = false

        enum CodingKeys: String, CodingKey {
            case initialized = "Initialized"
        }

        public init(from decoder: Decoder) {
            do {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                try values.decode(InitializedObj.self, forKey: .initialized)
                self.initialized = true
            } catch {
                self.initialized = false
            }
        }

        private struct InitializedObj: Codable {
        }
    }

    public func fetchClient(clientId: String) -> Promise<Client>  {
        return asyncGet(url: "\(baseUrl)/clients/\(clientId)") as Promise<Client>
    }

    public func createToken() -> Promise<AuthPlusToken>  {
        let postString = "grant_type=client_credentials"
        return asyncPostForm(url: "\(baseUrl)/token", body: postString) as Promise<AuthPlusToken>
    }

    public struct AuthPlusToken: Codable {
        let accessToken: String
        let expiresIn: Int
        let scope: String
        let tokenType: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
            case tokenType = "token_type"
            case scope = "scope"
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

