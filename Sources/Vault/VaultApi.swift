import Foundation
import PromiseKit
import MiniNetwork

public struct VaultHttpError: MiniNetworkError {
    public let code: Int?
    public let details: Error
}

public class VaultApi: MiniNetwork {
    public var baseUrl = "http://ota-crypt-vault"
    public var initCreds: VaultApi.InitCredentials?

    public override init() {}

    override public func errorObj(code: Int?, details: Error) -> MiniNetworkError {
        return VaultHttpError(code: code, details: details)
    }
}

public extension VaultApi {
    public struct InitializedStatus: Codable {
        let initialized: Bool
    }

    public struct InitBody: Codable {
        let secretShares = 5
        let secretThreshold = 3

        enum CodingKeys: String, CodingKey {
            case secretShares = "secret_shares"
            case secretThreshold = "secret_threshold"
        }
    }

    public struct InitCredentials: Codable {
        public let keys: [String]
        public let keysBase64: [String]
        public let rootToken: String

        enum CodingKeys: String, CodingKey {
            case keys = "keys"
            case keysBase64 = "keys_base64"
            case rootToken = "root_token"
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            // TODO: DRY up

            let keys = try values.decode([String].self, forKey: .keys)
            let rootToken = try values.decode(String.self, forKey: .rootToken)
            let keysBase64 = try values.decode([String].self, forKey: .keysBase64)

            let rt = rootToken.fromBase64()

            if rt != nil {
                // base64 encoded
                self.keys = keys.map({ key in
                    return key.fromBase64() ?? "Failed to decode"
                })
                self.keysBase64 = keysBase64.map({ keyBase64 in
                    return keyBase64.fromBase64() ?? "Failed to decode"
                })
                self.rootToken = rootToken.fromBase64() ?? "Failed to decode"
            } else {
                // just json
                self.keys = keys
                self.keysBase64 = keysBase64
                self.rootToken = rootToken
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(keys.map{$0.toBase64()}, forKey: .keys)
            try container.encode(keysBase64.map{$0.toBase64()}, forKey: .keysBase64)
            try container.encode(rootToken.toBase64(), forKey: .rootToken)
        }
    }

    public func fetchInitialised() -> Promise<InitializedStatus>  {
        return asyncGet(url: "\(baseUrl)/v1/sys/init") as Promise<InitializedStatus>
    }

    public func initializeServer() -> Promise<InitCredentials>  {
        return asyncPut(url: "\(baseUrl)/v1/sys/init", body: InitBody()) as Promise<InitCredentials>
    }
}

extension VaultApi {
    public struct Policies: Codable {
        let policies: [String]
    }
    public struct Policy: Codable {
    }
    public struct PolicyBody: Codable {
        public let name: String
        public let rules: String
        public let policyPath: String

        public init(name: String, policyPath: String) throws {
            self.name = name
            self.policyPath = policyPath

            self.rules = try StringLiteralType(contentsOf: URL(fileURLWithPath: policyPath), encoding: .utf8).replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\\\"", with: "\"", options: .literal)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(rules, forKey: .rules)
        }
    }

    public func fetchPolicies() -> Promise<Policies>  {
        return asyncGet(url: "\(baseUrl)/v1/sys/policy", headerParameters: ["X-Vault-Token": initCreds?.rootToken ?? ""]) as Promise<Policies>
    }

    public func createPolicy(policyBody: PolicyBody) -> Promise<Void>  {
        return asyncPutVoid(url: "\(baseUrl)/v1/sys/policy/\(policyBody.name)", body: policyBody, headerParameters: ["X-Vault-Token": initCreds?.rootToken ?? ""]) as Promise<Void>
    }
}

extension VaultApi {
    public struct Mounts: Codable {
        let sys: Mount

        enum CodingKeys: String, CodingKey {
            case sys = "sys/"
        }
    }
    public struct Mount: Codable {
        let default_lease_ttl: Int
    }
    public struct MountBody: Codable {
        public let path: String
        public let type: String

        public init(path: String, type: String) {
            self.path = path
            self.type = type
        }
    }

    public func fetchMount(mountBody: MountBody) -> Promise<Mount>  {
        return asyncGet(url: "\(baseUrl)/v1/sys/mounts\(mountBody.path)/tune", headerParameters: ["X-Vault-Token": initCreds?.rootToken ?? ""]) as Promise<Mount>
    }

    public func createMount(mountBody: MountBody) -> Promise<Mount>  {
        return asyncPost(url: "\(baseUrl)/v1/sys/mounts\(mountBody.path)", body: mountBody, headerParameters: ["X-Vault-Token": initCreds?.rootToken ?? ""]) as Promise<Mount>
    }

    public enum MountState {
        case exists(MountBody)
        case doesNotExist(MountBody)
    }

    public func checkMountState(mount: MountBody) -> Promise<MountState> {
        return Promise<MountState> { seal in
            firstly {
                self.fetchMount(mountBody: mount) as Promise<Mount>
            }.done { mountBody in
                seal.fulfill(MountState.exists(mount))
            }.catch { error in
                switch error {
                case is VaultHttpError:
                    seal.fulfill(MountState.doesNotExist(mount))
                default:
                    seal.reject(error)
                }
            }
        }
    }
}

extension VaultApi {
    public struct UnsealPayload: Codable {
        public let key: String

        public init(key: String) {
            self.key = key
        }
    }

    public struct UnsealStatus: Codable {
        public let sealed: Bool
        public let t: Int
        public let n: Int
        public let progress: Int
        public let version: String
    }

    public func unsealPut(key: UnsealPayload) -> Promise<UnsealStatus>  {
        return asyncPut(url: "\(baseUrl)/v1/sys/unseal", body: key) as Promise<UnsealStatus>
    }

    public func fetchSealStatus() -> Promise<UnsealStatus>  {
        return asyncGet(url: "\(baseUrl)/v1/sys/seal-status") as Promise<UnsealStatus>
    }
}
