// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SystemMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SystemMonitor",
            path: "Sources/SystemMonitor"
        ),
        // The app is one executable target and stays that way — testing it
        // directly works on macOS, and splitting a library out just to be
        // testable would move every file for no other gain.
        .testTarget(
            name: "SystemMonitorTests",
            dependencies: ["SystemMonitor"],
            path: "Tests/SystemMonitorTests"
        )
    ]
)
