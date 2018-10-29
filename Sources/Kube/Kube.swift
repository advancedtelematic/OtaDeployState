import struct Foundation.Data
import MiniNetwork
import PromiseKit
import Foundation

public final class Kube {
    public init() {}
    public let baseUrl = "http://localhost:8001"
    public let namespace = "default"

    public func fetchSecret<D: Codable>(name: String) -> Promise<Secret<D>>  {
        return asyncGet(url: "\(baseUrl)/api/v1/namespaces/\(namespace)/secrets/\(name)") as Promise<Secret>
    }

    public func createSecret<B: Codable, D: Codable>(name: String, body: B) -> Promise<Secret<D>>  {
        let secret = Secret(metadata: Secret.Metadata(name: name), data: body) as Secret<B>
        return asyncPost(url: "\(baseUrl)/api/v1/namespaces/\(namespace)/secrets", body: secret) as Promise<Secret>
    }

    public struct Secret<D: Codable>: Codable {
        public struct Metadata: Codable {
          let name: String
        }

        let apiVersion = "v1"
        let kind = "Secret"
        let type = "Opaque"
        let metadata: Metadata
        let data: D
    }

}
