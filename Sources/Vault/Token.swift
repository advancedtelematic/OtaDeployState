import PromiseKit
import Kube

extension VaultApi {
    public struct TokenK8s: Codable {
        public let vaultToken: String

        enum CodingKeys: String, CodingKey {
            case vaultToken = "VAULT_TOKEN"
        }

        public init(token: String) {
            self.vaultToken = token
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            // TODO: DRY up
            let vaultToken = try values.decode(String.self, forKey: .vaultToken)
            self.vaultToken = vaultToken.fromBase64() ?? "failed to from base64"
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(vaultToken.toBase64(), forKey: .vaultToken)
        }
    }

    public struct TokenCreateRequest: Codable {
        public let id: String?
        public let period: String
        public let policies: [String]
        public let displayName: String

        public init(period: String, policies: [String], displayName: String, id: String? = .none) {
            self.period = period
            self.policies = policies
            self.displayName = displayName
            self.id = id
        }

        enum CodingKeys: String, CodingKey {
            case period = "period"
            case policies = "policies"
            case displayName = "display_name"
            case id = "id"
        }
    }
    public struct TokenCreateResponse: Codable {
        public let auth: TokenCreateResponseDetails
    }
    public struct TokenCreateResponseDetails: Codable {
        public let policies: [String]
        public let clientToken: String

        enum CodingKeys: String, CodingKey {
            case policies = "policies"
            case clientToken = "client_token"
        }
    }

    public func createToken(tokenCreateRequest: TokenCreateRequest) -> Promise<TokenCreateResponse>  {
        return asyncPost(url: "\(baseUrl)/v1/auth/token/create", body: tokenCreateRequest, headerParameters: ["X-Vault-Token": initCreds?.rootToken ?? ""]) as Promise<TokenCreateResponse>
    }

    public struct TokenLookupRequest: Codable {
        public let token: String
    }
    public struct TokenLookupResponse: Codable {
        public let data: TokenLookupResponseDetails
    }
    public struct TokenLookupResponseDetails: Codable {
        public let ttl: Int
        public let policies: [String]
        public let displayName: String

        enum CodingKeys: String, CodingKey {
            case ttl = "ttl"
            case policies = "policies"
            case displayName = "display_name"
        }
    }
    public func lookupToken(tokenLookupRequest: TokenLookupRequest) -> Promise<TokenLookupResponse>  {
        return asyncPost(url: "\(baseUrl)/v1/auth/token/lookup", body: tokenLookupRequest, headerParameters: ["X-Vault-Token": initCreds?.rootToken ?? ""]) as Promise<TokenLookupResponse>
    }

}

public struct TokenState {
    let kube: Kube
    let vaultApi: VaultApi

    public init(kube: Kube?, vaultApi: VaultApi?) {
        self.kube = kube ?? Kube()
        self.vaultApi = vaultApi ?? VaultApi()
    }
    public enum State {
        case exists(VaultConfig.Token)
        case expiring(VaultConfig.Token)
        case doesNotExist(VaultConfig.Token)
        case ink8sOnly(VaultConfig.Token)
    }

    public func checkTokenState(token: VaultConfig.Token) -> Promise<State> {
        return Promise<State> { seal in
            firstly {
                self.kube.fetchSecret(name: token.displayName) as Promise<Kube.Secret<VaultApi.TokenK8s>>
            }.then({ secret in
                self.vaultApi.lookupToken(tokenLookupRequest: VaultApi.TokenLookupRequest(token: secret.data.vaultToken))
            }).done({ lookupToken in
                switch lookupToken.data.ttl {
                case 0...600:
                    seal.fulfill(State.expiring(token))
                default:
                    seal.fulfill(State.exists((token)))
                }
            }).catch({ (error) in
                switch error {
                case is VaultHttpError:
                    print("some vault error")
                    seal.fulfill(State.ink8sOnly(token))
                case is KubeHttpError:
                    print("some kube error")
                    seal.fulfill(State.doesNotExist(token))
                default:
                    print("some other error")
                    seal.reject(error)
                }
            })
        }
    }
}
