// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "memSnap",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "memSnap",
            path: "Sources/memSnap",
            exclude: ["Info.plist", "Assets"],
            linkerSettings: [
                .linkedFramework("Combine"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("IOKit")
            ]
        )
    ]
)
