// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OtaDeployState",
    dependencies: [
        .package(url: "https://github.com/IBM-Swift/SwiftyRequest.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/mxcl/PromiseKit.git", .upToNextMajor(from: "6.0.0")),
        .package(url: "https://github.com/PromiseKit/Foundation.git", .upToNextMajor(from: "3.0.0")),
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(name: "StateMachine", dependencies: []),
        .target(name: "OtaDeployState", dependencies: ["SwiftyRequest", "StateMachine", "PMKFoundation", "PromiseKit", "AuthPlus"]),
        .target(name: "AuthPlus", dependencies: ["SwiftyRequest", "StateMachine"]),
        .testTarget(
            name: "OtaDeployStateTests",
            dependencies: ["OtaDeployState"]),
    ]
)
