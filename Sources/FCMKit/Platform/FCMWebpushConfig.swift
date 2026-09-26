/// Web Push protocol overrides for an FCM message.
public struct FCMWebpushConfig: Encodable, Sendable {

    /// HTTP headers, e.g. `["TTL": "86400"]`.
    public var headers: [String: String]?

    /// Arbitrary key/value data delivered to the web app.
    public var data: [String: String]?

    /// Web notification options.
    public var notification: FCMWebpushNotification?

    public init(
        headers:      [String: String]?       = nil,
        data:         [String: String]?       = nil,
        notification: FCMWebpushNotification? = nil
    ) {
        self.headers      = headers
        self.data         = data
        self.notification = notification
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
