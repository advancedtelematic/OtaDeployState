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

    public struct Labels: Codable {
        let createdBy: String? = "OtaDeployState"
    }

    public struct Secret<D: Codable>: Codable {
        public struct Metadata: Codable {
            let name: String
            let labels: Labels

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
