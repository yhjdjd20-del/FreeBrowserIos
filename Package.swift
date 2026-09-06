// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrowserX",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "BrowserXCore", targets: ["BrowserXCore"])
    ],
    targets: [
        .target(
            name: "BrowserXCore",
            path: "BrowserX",
            exclude: ["App"] // App entry point остаётся в Xcode target, не в SPM
        ),
        .testTarget(
            name: "BrowserXCoreTests",
            dependencies: ["BrowserXCore"],
            path: "Tests/BrowserXCoreTests"
        )
    ]
)

// ПРИМЕЧАНИЕ:
// Этот Package.swift описывает переиспользуемое SPM-ядро (Models/Managers/Services/Utilities).
// Для полноценного iOS-приложения (SwiftUI App lifecycle, Info.plist, ассеты, подписи)
// используйте BrowserX.xcodeproj — см. XCODEPROJ.md в корне репозитория.
