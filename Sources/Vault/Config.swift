import Foundation

public final class VaultConfigs: Decodable {
    public let vaults: [VaultConfig]

    public init(path: URL) {
        let data = try! Data(contentsOf: path)
        let vcs = try! JSONDecoder().decode(VaultConfigs.self, from: data)
        self.vaults = vcs.vaults
    }
}

public final class VaultConfig: Decodable {
    public let name: String
    public let policies: [Policy]
    public let tokens: [Token]
    public let mounts: [Mount]
    public let url: String

    public struct Policy: Decodable {
        public let name: String
        public let pathToPolicy: String
    }
    public struct Token: Decodable {
        public let displayName: String
        public let policies: [String]
        public let period: String
    }
    public struct Mount: Decodable {
        public let path: String
        public let type: String
    }
}
