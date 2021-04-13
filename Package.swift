// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenDrop Base",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(name: "PSI", targets: ["PSI"]),
        .library(
            name: "OpenDrop Base",
            targets: ["OpenDrop Base"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.17.0"),
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.5.1"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.7.0"),
        .package(url: "https://github.com/Sn0wfreezeDev/ASN1Decoder.git", .branch("signatures")),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "1.0.2"),
        .package(
            url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.2.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(name: "PSI"),
        .target(
            name: "OpenDrop Base",
            dependencies: [
                "PSI",
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "ASN1Decoder", package: "ASN1Decoder"),
            ]),
        .testTarget(
            name: "OpenDrop BaseTests",
            dependencies: ["OpenDrop Base"]),
    ]
)
