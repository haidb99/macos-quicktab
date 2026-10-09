// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "QuickTab",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "QuickTab", targets: ["QuickTab"])],
    targets: [
        .target(name: "QuickTabCore"),
        .executableTarget(name: "QuickTabChecks", dependencies: ["QuickTabCore"]),
        .executableTarget(name: "QuickTab", dependencies: ["QuickTabCore"], linkerSettings: [
            .linkedFramework("AppKit"), .linkedFramework("SwiftUI"),
            .linkedFramework("ApplicationServices"), .linkedFramework("CoreGraphics"),
            .linkedFramework("ScreenCaptureKit"), .linkedFramework("ServiceManagement")
        ]),
        .testTarget(name: "QuickTabCoreTests", dependencies: ["QuickTabCore"])
    ]
)
