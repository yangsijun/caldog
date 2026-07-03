// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CaldogKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "CaldogKit", targets: ["CaldogKit"]),
    ],
    targets: [
        .target(
            name: "CaldogKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "CaldogKitTests",
            dependencies: ["CaldogKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
