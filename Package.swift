// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Nudgy",
    platforms: [.macOS(.v14)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Nudgy",
            dependencies: [],
            path: "Sources/Nudge",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "NudgyTests",
            dependencies: ["Nudgy"],
            path: "Tests/NudgeTests"
        ),
    ]
)
