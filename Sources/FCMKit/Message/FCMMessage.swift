/// An FCM HTTP v1 message.
///
/// Exactly one of `token`, `topic`, or `condition` must be set — enforced at
/// the type level via ``Target``.
///
/// ```swift
/// let msg = FCMMessage(
///     target: .token("device-registration-token"),
///     notification: FCMNotification(title: "Hello", body: "World"),
///     data: ["deeplink": "/home"]
/// )
/// ```
public struct FCMMessage: Encodable, Sendable {

    // MARK: - Target

    /// The delivery target for the message.
    public enum Target: Sendable {
        /// A single device registration token.
        case token(String)
        /// A topic name (without the `/topics/` prefix).
        case topic(String)
        /// A boolean condition expression, e.g. `"'TopicA' in topics"`.
        case condition(String)
    }

    // MARK: - Properties

    public let target: Target

    /// Base notification shown on all platforms.
    public var notification: FCMNotification?

    /// Arbitrary key/value data delivered to the app.
    public var data: [String: String]?

    /// Android-specific overrides.
    public var android: FCMAndroidConfig?

    /// APNS (Apple Push Notification service) overrides.
    public var apns: FCMAPNSConfig?

    /// Web-push overrides.
    public var webpush: FCMWebpushConfig?

    // MARK: - Init

    public init(
        target:       Target,
        notification: FCMNotification?  = nil,
        data:         [String: String]? = nil,
        android:      FCMAndroidConfig? = nil,
        apns:         FCMAPNSConfig?    = nil,
        webpush:      FCMWebpushConfig? = nil
    ) {
        self.target       = target
        self.notification = notification
        self.data         = data
        self.android      = android
        self.apns         = apns
        self.webpush      = webpush
    }

    // MARK: - Encodable

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        switch target {
        case .token(let v):     try c.encode(v, forKey: .token)
        case .topic(let v):     try c.encode(v, forKey: .topic)
        case .condition(let v): try c.encode(v, forKey: .condition)
        }

        try c.encodeIfPresent(notification, forKey: .notification)
        try c.encodeIfPresent(data,         forKey: .data)
        try c.encodeIfPresent(android,      forKey: .android)
        try c.encodeIfPresent(apns,         forKey: .apns)
        try c.encodeIfPresent(webpush,      forKey: .webpush)
    }

    private enum CodingKeys: String, CodingKey {
        case token, topic, condition
        case notification, data, android, apns, webpush
    }
}
