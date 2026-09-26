// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "fcm-kit",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        // Core FCM client library
        .library(name: "FCMKit", targets: ["FCMKit"]),
        // Test support — import in test targets only
        .library(name: "FCMKitTestSupport", targets: ["FCMKitTestSupport"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-server/async-http-client.git",
            from: "1.36.1"
        ),
        .package(
            url: "https://github.com/vapor/jwt-kit.git",
            from: "5.7.1"
        ),
        .package(
            url: "https://github.com/apple/swift-nio.git",
            from: "2.103.0"
        ),
    ],
    targets: [
        // ── Library ────────────────────────────────────────────────────────────
        .target(
            name: "FCMKit",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "JWTKit",          package: "jwt-kit"),
                .product(name: "NIOCore",          package: "swift-nio"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),

        // ── Test support ───────────────────────────────────────────────────────
        // Import FCMKitTestSupport in your test targets to get MockFCMClient.
        .target(
            name: "FCMKitTestSupport",
            dependencies: ["FCMKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),

        // ── Runnable example ───────────────────────────────────────────────────
        .executableTarget(
            name: "FCMKitExample",
            dependencies: [
                "FCMKit",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),

        // ── Tests ──────────────────────────────────────────────────────────────
        .testTarget(
            name: "FCMKitTests",
            dependencies: [
                "FCMKit",
                "FCMKitTestSupport",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
