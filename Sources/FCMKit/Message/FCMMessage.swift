/// An FCM HTTP v1 message.
///
/// Exactly one delivery target must be set — enforced at the type level via ``Target``.
///
/// ```swift
/// let msg = FCMMessage(
///     target: .fid("device-registration-token-or-fid"),
///     notification: FCMNotification(title: "Hello", body: "World"),
///     data: ["deeplink": "/home"]
/// )
/// ```
public struct FCMMessage: Encodable, Sendable {

    // MARK: - Target

    /// The delivery target for the message.
    public enum Target: Sendable {
        /// A Firebase Installation ID (FID) or device registration token.
        ///
        /// Encodes as the `"fid"` JSON field, which replaced the deprecated `"token"` field.
        case fid(String)
        /// A topic name (without the `/topics/` prefix).
        case topic(String)
        /// A boolean condition expression, e.g. `"'sport' in topics && 'tech' in topics"`.
        case condition(String)
    }

    // MARK: - Properties

    public let target: Target

    /// Base notification displayed on all platforms.
    public var notification: FCMNotification?

    /// Arbitrary key/value data delivered to the app (UTF-8, max 4 KB total).
    ///
    /// Keys must not start with `"google."`, `"gcm."`, or equal `"from"` / `"message_type"`.
    public var data: [String: String]?

    /// Android-specific overrides.
    public var android: FCMAndroidConfig?

    /// APNS (Apple Push Notification service) overrides.
    public var apns: FCMAPNSConfig?

    /// Web Push overrides.
    public var webpush: FCMWebpushConfig?

    /// Cross-platform FCM SDK feature options (e.g. analytics label).
    public var fcmOptions: FCMOptions?

    // MARK: - Init

    public init(
        target:       Target,
        notification: FCMNotification?  = nil,
        data:         [String: String]? = nil,
        android:      FCMAndroidConfig? = nil,
        apns:         FCMAPNSConfig?    = nil,
        webpush:      FCMWebpushConfig? = nil,
        fcmOptions:   FCMOptions?       = nil
    ) {
        self.target       = target
        self.notification = notification
        self.data         = data
        self.android      = android
        self.apns         = apns
        self.webpush      = webpush
        self.fcmOptions   = fcmOptions
    }

    // MARK: - Encodable

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        switch target {
        case .fid(let v):       try c.encode(v, forKey: .fid)
        case .topic(let v):     try c.encode(v, forKey: .topic)
        case .condition(let v): try c.encode(v, forKey: .condition)
        }

        try c.encodeIfPresent(notification, forKey: .notification)
        try c.encodeIfPresent(data,         forKey: .data)
        try c.encodeIfPresent(android,      forKey: .android)
        try c.encodeIfPresent(apns,         forKey: .apns)
        try c.encodeIfPresent(webpush,      forKey: .webpush)
        try c.encodeIfPresent(fcmOptions,   forKey: .fcmOptions)
    }

    private enum CodingKeys: String, CodingKey {
        case fid, topic, condition
        case notification, data, android, apns, webpush
        case fcmOptions = "fcm_options"
    }
}
