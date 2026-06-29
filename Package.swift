// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DockCycle",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "DockCycle",
            path: "Sources/DockCycle"
        )
    ]
)
