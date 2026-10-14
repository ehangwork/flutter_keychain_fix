// swift-tools-version: 5.9
// Flutter Swift Package Manager support.
// See: https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors

import PackageDescription

let package = Package(
    name: "flutter_keychain_fix",
    platforms: [
        .iOS(.v12),
    ],
    products: [
        .library(
            name: "flutter-keychain-fix",
            targets: ["flutter_keychain_fix"]
        ),
    ],
    dependencies: [
        // Required: the plugin imports Flutter. Without this dependency Flutter refuses
        // to build the package and prints migration instructions.
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "flutter_keychain_fix",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: "Sources/flutter_keychain_fix"
        ),
    ]
)