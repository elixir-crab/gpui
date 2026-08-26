// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DesktopDriver",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "gpui-desktop-driver", targets: ["DesktopDriver"])
    ],
    targets: [
        .executableTarget(name: "DesktopDriver")
    ]
)
