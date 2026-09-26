// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "fcm-kit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "FCMKit", targets: ["FCMKit"]),
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
            dependencies: ["FCMKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
