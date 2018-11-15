// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OtaDeployState",
    dependencies: [
        .package(url: "https://github.com/IBM-Swift/SwiftyRequest.git", .branch("master")),
        .package(url: "https://github.com/mxcl/PromiseKit.git", .upToNextMajor(from: "6.0.0")),
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(name: "StateMachine", dependencies: []),
        .target(name: "OtaDeployState", dependencies: ["SwiftyRequest", "StateMachine", "PromiseKit", "AuthPlus", "Kube", "Vault"]),
        .target(name: "AuthPlus", dependencies: ["MiniNetwork", "SwiftyRequest", "StateMachine", "Kube", "PromiseKit"]),
        .target(name: "Vault", dependencies: ["MiniNetwork", "SwiftyRequest", "StateMachine", "Kube", "PromiseKit"]),
        .target(name: "MiniNetwork", dependencies: ["SwiftyRequest", "PromiseKit"]),
        .target(name: "Kube", dependencies: ["MiniNetwork", "PromiseKit"]),

        .testTarget(
            name: "OtaDeployStateTests",
            dependencies: ["OtaDeployState"]),
    ]
)
