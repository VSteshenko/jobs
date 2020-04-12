// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "jobs",
    platforms: [
       .macOS(.v10_15)
    ],
    products: [
        .library(name: "Jobs", targets: ["Jobs"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.1")
    ],
    targets: [
        .target(name: "Jobs", dependencies: [
            .product(name: "Vapor", package: "vapor"),
        ]),
        .testTarget(name: "JobsTests", dependencies: [
            .target(name: "Jobs"),
            .target(name: "XCTVapor"),
        ]),
    ]
)
