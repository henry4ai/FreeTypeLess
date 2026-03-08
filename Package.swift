// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SwiftTypeless",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "SwiftTypeless",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            path: "Sources/SwiftTypeless",
            resources: [
                .copy("../../Resources")
            ]
        )
    ]
)
