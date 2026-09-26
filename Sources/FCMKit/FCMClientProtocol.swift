// MARK: - FCMClientProtocol

/// An abstraction over ``FCMClient`` that makes it easy to inject test doubles.
///
/// Depend on `any FCMClientProtocol` in your application types rather than
/// the concrete ``FCMClient``, then swap in ``MockFCMClient`` (from
/// `FCMKitTestSupport`) during tests:
///
/// ```swift
/// // Production code — depends on the protocol, not the concrete class
/// struct NotificationService {
///     let fcm: any FCMClientProtocol
///
///     func notify(token: String, title: String, body: String) async throws {
///         try await fcm.send(
///             FCMMessage(target: .fid(token),
///                        notification: FCMNotification(title: title, body: body))
///         )
///     }
/// }
///
/// // In your app
/// let service = NotificationService(fcm: try FCMClient(
///     credentials: account, httpClient: .shared,
///     decoder: JSONDecoder(), encoder: JSONEncoder()
/// ))
/// ```
///
/// > Note: Generic methods (both `sendLiveActivity` overloads) are not
/// > included because protocol requirements cannot have unconstrained generic parameters.
/// > Test Live Activity sends using ``FCMClientProtocol/send(_:validateOnly:)`` with
/// > `validateOnly: true`, or build the APS payload in isolation and assert on it directly.
public protocol FCMClientProtocol: Sendable {

    // MARK: - Send

    /// Sends a single FCM message.
    ///
    /// - Parameters:
    ///   - message:      The message to deliver.
    ///   - validateOnly: When `true` the message is validated by FCM but not delivered.
    /// - Returns: The FCM message name.
    /// - Throws: ``FCMError`` on network or server failure.
    @discardableResult
    func send(_ message: FCMMessage, validateOnly: Bool) async throws -> String

    /// Sends multiple messages concurrently.
    ///
    /// - Parameter messages: Messages to send. Order is preserved in the result.
    /// - Returns: Per-message `Result` values aligned with `messages`.
    /// - Throws: ``FCMError`` if the OAuth token cannot be fetched before task spawning.
    func sendBatch(_ messages: [FCMMessage]) async throws -> [Result<String, any Error>]

    // MARK: - Topic subscriptions

    /// Creates a new topic subscription. Fails if one already exists.
    ///
    /// - Parameters:
    ///   - fid:   Firebase Installation ID or FCM registration token.
    ///   - topic: Topic name without the `/topics/` prefix.
    /// - Returns: The newly created ``FCMTopicSubscription``.
    /// - Throws: ``FCMError`` on failure or if the subscription already exists.
    @discardableResult
    func createSubscription(fid: String, to topic: String) async throws -> FCMTopicSubscription

    /// Subscribes a device to a topic (idempotent upsert).
    ///
    /// - Parameters:
    ///   - fid:   Firebase Installation ID or FCM registration token.
    ///   - topic: Topic name without the `/topics/` prefix.
    /// - Returns: The ``FCMTopicSubscription`` (new or existing).
    /// - Throws: ``FCMError`` on failure.
    @discardableResult
    func subscribe(fid: String, to topic: String) async throws -> FCMTopicSubscription

    /// Unsubscribes a device from a topic (idempotent).
    ///
    /// - Parameters:
    ///   - fid:   Firebase Installation ID or FCM registration token.
    ///   - topic: Topic name without the `/topics/` prefix.
    /// - Throws: ``FCMError`` on failure.
    func unsubscribe(fid: String, from topic: String) async throws

    /// Returns the subscription for a specific device and topic.
    ///
    /// - Parameters:
    ///   - fid:   Firebase Installation ID or FCM registration token.
    ///   - topic: Topic name without the `/topics/` prefix.
    /// - Returns: The ``FCMTopicSubscription``.
    /// - Throws: ``FCMError/serverError(status:code:message:)`` with
    ///   ``FCMServerErrorCode/unregistered`` if the subscription does not exist.
    func getSubscription(fid: String, topic: String) async throws -> FCMTopicSubscription

    /// Lists all topic subscriptions for a device.
    ///
    /// - Parameters:
    ///   - fid:       Firebase Installation ID or FCM registration token.
    ///   - pageSize:  Maximum results per page (max 2 000).
    ///   - pageToken: Continuation token; `nil` for the first page.
    /// - Returns: A ``FCMTopicSubscriptionsPage``.
    /// - Throws: ``FCMError`` on failure.
    func listSubscriptions(
        fid:       String,
        pageSize:  Int,
        pageToken: String?
    ) async throws -> FCMTopicSubscriptionsPage
}

// MARK: - Default parameter shims
//
// Protocols cannot declare default parameter values, so these extensions
// restore the convenience defaults that FCMClient already provides.

extension FCMClientProtocol {

    /// Sends a message without the `validateOnly` flag (default: `false`).
    @discardableResult
    public func send(_ message: FCMMessage) async throws -> String {
        try await send(message, validateOnly: false)
    }

    /// Lists subscriptions using default paging values.
    public func listSubscriptions(fid: String) async throws -> FCMTopicSubscriptionsPage {
        try await listSubscriptions(fid: fid, pageSize: 1_000, pageToken: nil)
    }
}

// MARK: - FCMClient conformance

extension FCMClient: FCMClientProtocol {}
