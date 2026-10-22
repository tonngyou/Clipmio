// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Clipmio",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Clipmio", targets: ["Clipmio"])],
    targets: [
        .target(name: "ClipmioCore"),
        .executableTarget(
            name: "Clipmio", dependencies: ["ClipmioCore"],
            resources: [.process("Resources")],
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        ),
        .testTarget(name: "ClipmioCoreTests", dependencies: ["ClipmioCore"]),
        .testTarget(name: "ClipmioTests", dependencies: ["Clipmio", "ClipmioCore"])
    ]
)
