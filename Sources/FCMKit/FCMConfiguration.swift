import Foundation
import NIOCore

/// Tuning parameters for ``FCMClient``.
///
/// Pass a customised value to ``FCMClient/init(credentials:httpClient:decoder:encoder:byteBufferAllocator:configuration:)``
/// or rely on ``FCMConfiguration/default`` for sensible production defaults.
///
/// ```swift
/// let config = FCMConfiguration(requestTimeout: 10, maxResponseSize: 512_000)
/// let client = try FCMClient(credentials: account, httpClient: httpClient,
///                            decoder: JSONDecoder(), encoder: JSONEncoder(),
///                            configuration: config)
/// ```
public struct FCMConfiguration: Sendable {

    /// Per-request network timeout in seconds. Default: `30`.
    public var requestTimeout: TimeInterval

    /// Maximum bytes read from any single FCM response body.
    /// Responses larger than this limit throw ``FCMError/decodingFailed(_:)``. Default: `1 048 576` (1 MB).
    public var maxResponseSize: Int

    /// Production-ready defaults: 30 s timeout, 1 MB max response.
    public static let `default` = FCMConfiguration()

    public init(
        requestTimeout:  TimeInterval = 30,
        maxResponseSize: Int = 1_048_576
    ) {
        self.requestTimeout  = requestTimeout
        self.maxResponseSize = maxResponseSize
    }

    // MARK: - Internal helpers

    var requestTimeoutAmount: TimeAmount {
        .milliseconds(Int64(requestTimeout * 1_000))
    }
}
