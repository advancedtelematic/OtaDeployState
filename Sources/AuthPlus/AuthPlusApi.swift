import Foundation
import PromiseKit
import SwiftyRequest
import enum SwiftyRequest.Result
import StateMachine
import MiniNetwork

public struct AuthPlusApi {
    public let baseUrl = "http://ota-auth-plus"
    public init() {}
}

public extension AuthPlusApi {
    public func fetchInitialised() -> Promise<InitialisedStatus>  {
        return asyncGet(url: "\(baseUrl)/init") as Promise<InitialisedStatus>
    }

    private struct InitialiseBody: Encodable {
        let clientName = "ota-auth-plus-admin"
        let grantTypes = ["client_credentials"]
        let scope = "client.register client.update"

        enum CodingKeys: String, CodingKey {
            case clientName = "client_name"
            case grantTypes = "grant_types"
            case scope = "scope"
        }
    }

    public func initialiseServer() -> Promise<Client>  {
        return asyncPost(url: "\(baseUrl)/init", body: InitialiseBody()) as Promise<Client>
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
}

public extension AuthPlusApi {
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

public extension AuthPlusApi {
    public func fetchClient(clientId: String) -> Promise<Client>  {
        return asyncGet(url: "\(baseUrl)/clients/\(clientId)") as Promise<Client>
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
}
