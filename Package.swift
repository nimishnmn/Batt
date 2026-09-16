// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Batt",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Batt", targets: ["Batt"])
    ],
    targets: [
        .executableTarget(
            name: "Batt",
            path: "Sources/Batt",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox")
            ]
        ),
        .testTarget(
            name: "BattTests",
            dependencies: ["Batt"],
            path: "Tests/BattTests"
        )
    ]
)
