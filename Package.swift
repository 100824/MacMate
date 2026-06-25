// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MacMate",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacMate", targets: ["MacMate"])
    ],
    targets: [
        .executableTarget(
            name: "MacMate",
            resources: [.process("Resources")],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
