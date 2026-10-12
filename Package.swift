// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Mactivity",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Mactivity",
            path: "Sources/Mactivity",
            linkerSettings: [
                .linkedFramework("CoreWLAN"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("Network"),
                .linkedFramework("SystemConfiguration")
            ]
        )
    ]
)
