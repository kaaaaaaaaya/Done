// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TaskManagement",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TaskManagement", targets: ["TaskManagement"])
    ],
    targets: [
        .executableTarget(
            name: "TaskManagement",
            path: "Sources/TaskManagement"
        )
    ]
)
