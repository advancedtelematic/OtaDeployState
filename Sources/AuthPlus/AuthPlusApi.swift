import Foundation
import PromiseKit
import MiniNetwork

public struct AuthPlusHttpError: MiniNetworkError {
    public let code: Int?
    public let details: Error
}

public class AuthPlusApi: MiniNetwork {
    public let baseUrl = getEnvironmentVar("AUTH_PLUS_URL") ?? "http://ota-auth-plus"
    public var token: AuthPlusToken?
    public var adminClient: Client?

    public override init() {}
    
    override public func errorObj(code: Int?, details: Error) -> MiniNetworkError {
        return AuthPlusHttpError(code: code, details: details)
    }
}

public extension AuthPlusApi {
    public func fetchInitialised() -> Promise<InitialisedStatus>  {
        return asyncGet(url: "\(baseUrl)/init") as Promise<InitialisedStatus>
    }

    public struct ClientMetadata: Codable {
        let clientName: String
        let grantTypes: [String]
        let scope: String

        enum CodingKeys: String, CodingKey {
            case clientName = "client_name"
            case grantTypes = "grant_types"
            case scope = "scope"
        }
    }

    public func initialiseServer() -> Promise<Client>  {
        let clientMetadata = ClientMetadata(clientName: "ota-auth-plus-admin",
                                            grantTypes: ["client_credentials"],
                                            scope: "client.register client.update")
        return asyncPost(url: "\(baseUrl)/init", body: clientMetadata) as Promise<Client>
    }

    public struct InitialisedStatus: Decodable {
        public let initialized: Bool

        enum CodingKeys: String, CodingKey {
            case initialized = "Initialized"
        }

        public init(from decoder: Decoder) {
            do {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                _ = try values.decode(InitializedObj.self, forKey: .initialized)
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
    public func createToken(for client: Client) -> Promise<AuthPlusToken>  {
        let postString = "grant_type=client_credentials"
        return asyncPostForm(url: "\(baseUrl)/token", body: postString, clientId: client.clientId, clientSecret: client.clientSecret) as Promise<AuthPlusToken>
    }

    public struct AuthPlusToken: Codable {
        public let accessToken: String
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
        return asyncGet(url: "\(baseUrl)/clients/\(clientId)", token: token?.accessToken) as Promise<Client>
    }

    public func create(client: ClientMetadata) -> Promise<Client>  {
        return asyncPost(url: "\(baseUrl)/clients", body: client, token: token?.accessToken) as Promise<Client>
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

        public init(clientId: String, clientSecret: String, clientName: String) {
            self.clientId = clientId
            self.clientSecret = clientSecret
            self.clientName = clientName
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            // TODO: DRY up
            let clientIdString = try values.decode(String.self, forKey: .clientId)
            self.clientId = clientIdString.fromBase64() ?? clientIdString

            let clientSecretString = try values.decode(String.self, forKey: .clientSecret)
            self.clientSecret = clientSecretString.fromBase64() ?? clientSecretString

            let clientNameString = try values.decode(String.self, forKey: .clientName)
            self.clientName = clientNameString.fromBase64() ?? clientNameString
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(clientId.toBase64(), forKey: .clientId)
            try container.encode(clientSecret.toBase64(), forKey: .clientSecret)
            try container.encode(clientName.toBase64(), forKey: .clientName)
        }
    }
}

extension String {
    func fromBase64() -> String? {
        guard let data = Data(base64Encoded: self) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }
}
