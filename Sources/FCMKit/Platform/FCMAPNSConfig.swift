/// Apple Push Notification service (APNS) overrides for an FCM message.
public struct FCMAPNSConfig: Encodable, Sendable {

    /// HTTP/2 request headers, e.g. `["apns-priority": "10"]`.
    public var headers: [String: String]?

    /// APNs payload (contains the `aps` dictionary and any custom keys).
    public var payload: FCMAPNSPayload?

    public init(
        headers: [String: String]? = nil,
        payload: FCMAPNSPayload?   = nil
    ) {
        self.headers = headers
        self.payload = payload
    }
}

// MARK: -

/// APNs payload wrapper. Add custom keys alongside `aps` by subclassing or
/// encoding manually; the provided type covers the most common fields.
public struct FCMAPNSPayload: Encodable, Sendable {

    public var aps: FCMAPS

    public init(aps: FCMAPS) {
        self.aps = aps
    }
}

// MARK: -

/// The `aps` dictionary of an APNs payload.
///
/// `contentAvailable` and `mutableContent` are `Double?` so that passing `1`
/// serialises to the JSON integer `1` — exactly what APNs requires on the wire.
/// A JSON boolean `true` is a different token and is not accepted by APNs.
public struct FCMAPS: Encodable, Sendable {

    public var alert:            FCMAPSAlert?
    /// Badge count to display on the app icon.
    public var badge:            Int?
    /// Sound name, or `"default"` for the system sound.
    public var sound:            String?
    /// Pass `1` to deliver a background notification without user-visible UI.
    public var contentAvailable: Double?
    /// Pass `1` to allow the Notification Service Extension to modify the payload.
    public var mutableContent:   Double?
    public var category:         String?
    /// Groups related notifications under the same thread identifier.
    public var threadID:         String?

    public init(
        alert:            FCMAPSAlert? = nil,
        badge:            Int?         = nil,
        sound:            String?      = nil,
        contentAvailable: Double?      = nil,
        mutableContent:   Double?      = nil,
        category:         String?      = nil,
        threadID:         String?      = nil
    ) {
        self.alert            = alert
        self.badge            = badge
        self.sound            = sound
        self.contentAvailable = contentAvailable
        self.mutableContent   = mutableContent
        self.category         = category
        self.threadID         = threadID
    }

    private enum CodingKeys: String, CodingKey {
        case alert, badge, sound, category
        case contentAvailable = "content-available"
        case mutableContent   = "mutable-content"
        case threadID         = "thread-id"
    }
}

// MARK: -

/// The `alert` dictionary inside `aps`.
public struct FCMAPSAlert: Encodable, Sendable {

    public var title:    String?
    public var subtitle: String?
    public var body:     String?

    public init(
        title:    String? = nil,
        subtitle: String? = nil,
        body:     String? = nil
    ) {
        self.title    = title
        self.subtitle = subtitle
        self.body     = body
    }
}
