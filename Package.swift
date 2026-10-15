// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SVGCleaner",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "SVGCleaner")
    ],
    swiftLanguageModes: [.v5]
)
