// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SwamiTool",
    platforms: [.macOS(.v13)],
    targets: [.executableTarget(name: "SwamiTool", path: "Sources/SwamiTool")]
)
