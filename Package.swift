// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NoLock",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "NoLock", targets: ["NoLock"])],
    targets: [
        .target(name: "NoLockCore"),
        .executableTarget(name: "NoLock", dependencies: ["NoLockCore"]),
        .testTarget(name: "NoLockCoreTests", dependencies: ["NoLockCore"]),
    ]
)
