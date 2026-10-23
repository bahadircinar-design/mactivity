// swift-tools-version: 6.2
import PackageDescription

/// Folio’s shared models and views. The runnable iOS app lives in `Folio.xcodeproj`.
let package = Package(
    name: "Folio",
    platforms: [
        .iOS("27.0")
    ],
    products: [
        .library(name: "FolioCore", targets: ["FolioCore"])
    ],
    targets: [
        .target(
            name: "FolioCore",
            path: "Sources/Folio",
            exclude: ["App"]
        )
    ]
)
