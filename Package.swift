// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LLMChat",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "LLMChat",
            targets: ["LLMChat"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.3.0"),
        .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "LLMChat",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Algorithms", package: "swift-algorithms"),
            ]
        ),
        .testTarget(
            name: "LLMChatTests",
            dependencies: ["LLMChat"]
        ),
    ]
)