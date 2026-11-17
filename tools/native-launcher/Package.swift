// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WineSupervisor",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "WineSupervisor", targets: ["WineSupervisor"])
    ],
    targets: [
        .executableTarget(name: "WineSupervisor"),
        .testTarget(name: "WineSupervisorTests", dependencies: ["WineSupervisor"])
    ]
)
