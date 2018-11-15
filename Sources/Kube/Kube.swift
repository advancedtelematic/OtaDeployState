import struct Foundation.Data
import MiniNetwork
import PromiseKit
import Foundation

public struct KubeHttpError: MiniNetworkError {
    public let code: Int?
    public let details: Error
}

public final class Kube: MiniNetwork {
    public override init() {}
    public let baseUrl = "http://localhost:8001"
    public let namespace = "default"

    override public func errorObj(code: Int?, details: Error) -> MiniNetworkError {
        return KubeHttpError(code: code, details: details)
    }

    public func fetchSecret<D: Codable>(name: String) -> Promise<Secret<D>>  {
        return asyncGet(url: "\(baseUrl)/api/v1/namespaces/\(namespace)/secrets/\(name)") as Promise<Secret>
    }

    public func createSecret<B: Codable, D: Codable>(name: String, body: B) -> Promise<Secret<D>>  {
        let secret = Secret(metadata: Secret.Metadata(name: name), data: body) as Secret<B>
        return asyncPost(url: "\(baseUrl)/api/v1/namespaces/\(namespace)/secrets", body: secret) as Promise<Secret>
    }

    public func updateSecret<B: Codable, D: Codable>(name: String, body: B) -> Promise<Secret<D>>  {
        let secret = Secret(metadata: Secret.Metadata(name: name), data: body) as Secret<B>
        return asyncPut(url: "\(baseUrl)/api/v1/namespaces/\(namespace)/secrets/\(name)", body: secret) as Promise<Secret>
    }

    public func updateSecretJsonBlob<B: Codable>(name: String, body: B) -> Promise<Secret<JsonBlob<B>>>  {
        let jsonBlob = JsonBlob(blob: body) as JsonBlob<B>
        let secret = Secret(metadata: Secret.Metadata(name: name), data: jsonBlob) as Secret<JsonBlob>
        return asyncPut(url: "\(baseUrl)/api/v1/namespaces/\(namespace)/secrets/\(name)", body: secret) as Promise<Secret>
    }

    public struct Labels: Codable {
        let createdBy: String? = "OtaDeployState"
        let requiredBy: String? = "Ota"
    }

    public struct JsonBlob<B: Codable>: Codable {
        public let blob: B

        public init(blob: B) {
            self.blob = blob
        }

        enum CodingKeys: String, CodingKey {
            case blob = "blob"
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            let jsonValue = try values.decode(String.self, forKey: .blob).fromBase64()
            self.blob = try! JSONDecoder().decode(B.self, from: (jsonValue?.data(using: .utf8))!)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            let jsonValue = try? JSONEncoder().encode(blob)
            let base64Value = String(data: jsonValue!, encoding: .utf8)?.toBase64()

            try container.encode(base64Value, forKey: .blob)
        }
    }

    public struct Secret<D: Codable>: Codable {
        public struct Metadata: Codable {
            let name: String
            let labels: Labels?

            public init(name: String) {
                self.name = name
                self.labels = Labels()
            }
        }

        public let apiVersion = "v1"
        public let kind = "Secret"
        public let type = "Opaque"
        public let metadata: Metadata
        public let data: D
    }

}
