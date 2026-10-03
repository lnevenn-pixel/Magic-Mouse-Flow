// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MagicMouseFlow",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MagicMouseFlow", targets: ["MagicMouseFlow"])
    ],
    targets: [
        .target(
            name: "MagicMouseBridge",
            path: "Sources/MagicMouseBridge",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("CoreFoundation")
            ]
        ),
        .executableTarget(
            name: "MagicMouseFlow",
            dependencies: ["MagicMouseBridge"],
            path: "Sources/MagicMouseFlow",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices")
            ]
        )
    ]
)
