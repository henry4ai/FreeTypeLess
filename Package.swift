// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SwiftTypeless",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SwiftTypeless",
            path: "Sources/SwiftTypeless",
            resources: [
                .copy("../../Resources")
            ]
        )
    ]
)
