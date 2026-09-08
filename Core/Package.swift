// swift-tools-version: 6.0
import PackageDescription

// FinalScoreCore is the platform-agnostic heart of the app: all business logic
// lives here. It depends on nothing but the standard library + Foundation,
// so its behavior is unit-tested with `swift test` on any platform — no
// Xcode or simulator required. The iOS app target in App/ is a thin UI
// layer on top.
let package = Package(
    name: "FinalScoreCore",
    products: [
        .library(name: "FinalScoreCore", targets: ["FinalScoreCore"]),
    ],
    targets: [
        .target(name: "FinalScoreCore"),
        .testTarget(
            name: "FinalScoreCoreTests",
            dependencies: ["FinalScoreCore"]
        ),
    ]
)
