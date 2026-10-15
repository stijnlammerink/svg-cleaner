// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SVGCleaner",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "SVGCleaner")
    ],
    swiftLanguageModes: [.v5]
)
