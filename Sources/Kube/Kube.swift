import struct Foundation.Data
import MiniNetwork
import PromiseKit
import Foundation

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

public final class Kube {
    public init() {}
    public let baseUrl = "http://localhost:8001"
    public let namespace = "default"

    public func fetchSecret(name: String) -> Promise<Secret>  {
        return asyncGet(url: "\(baseUrl)/api/v1/namespaces/\(namespace)/secrets/\(name)") as Promise<Secret>
    }

    public struct Secret: Codable {
        public struct Metadata: Codable {
          let name: String
        }

        public struct Data: Codable {
            let clientId: String?
            let clientSecret: String?

            enum CodingKeys: String, CodingKey {
                case clientId = "client_id"
                case clientSecret = "client_secret"
            }

            public init(from decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                self.clientId = try values.decode(String.self, forKey: .clientId).fromBase64()
                self.clientSecret = try values.decode(String.self, forKey: .clientSecret).fromBase64()
            }

            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(clientId?.toBase64(), forKey: .clientId)
                try container.encode(clientSecret?.toBase64(), forKey: .clientSecret)
            }
        }

        let apiVersion = "v1"
        let kind = "Secret"
        let type = "Opaque"
        let metadata: Metadata
        let data: Data
    }

}
