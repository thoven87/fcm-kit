/// Web Push protocol overrides for an FCM message.
public struct FCMWebpushConfig: Encodable, Sendable {

    /// HTTP headers forwarded to the Web Push endpoint, e.g. `["TTL": "86400"]`.
    public var headers: [String: String]?

    /// Arbitrary key/value data delivered to the web app.
    /// Overrides the message-level ``FCMMessage/data``.
    public var data: [String: String]?

    /// Web Notification API options.
    public var notification: FCMWebpushNotification?

    /// FCM SDK feature options for Web (deep-link and analytics label).
    public var fcmOptions: FCMWebpushOptions?

    public init(
        headers:      [String: String]?       = nil,
        data:         [String: String]?       = nil,
        notification: FCMWebpushNotification? = nil,
        fcmOptions:   FCMWebpushOptions?      = nil
    ) {
        self.headers      = headers
        self.data         = data
        self.notification = notification
        self.fcmOptions   = fcmOptions
    }

    private enum CodingKeys: String, CodingKey {
        case headers, data, notification
        case fcmOptions = "fcm_options"
    }
}

// MARK: -

/// Web Push Notification API fields.
public struct FCMWebpushNotification: Encodable, Sendable {

    public var title: String?
    public var body:  String?
    /// URL of the icon displayed in the notification.
    public var icon:  String?

    public init(
        title: String? = nil,
        body:  String? = nil,
        icon:  String? = nil
    ) {
        self.title = title
        self.body  = body
        self.icon  = icon
    }
}
