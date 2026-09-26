/// Android-specific message configuration.
public struct FCMAndroidConfig: Encodable, Sendable {

    // MARK: - Priority

    public enum Priority: String, Encodable, Sendable {
        case normal = "NORMAL"
        case high   = "HIGH"
    }

    // MARK: - Properties

    /// Identifies a group of messages that can be collapsed.
    public var collapseKey: String?

    /// Message priority.
    public var priority: Priority?

    /// Time-to-live duration string, e.g. `"3.5s"`. See Google Duration format.
    public var ttl: String?

    /// Package name of the application where the registration token must match.
    public var restrictedPackageName: String?

    /// Arbitrary key/value data. Overrides the message-level `data`.
    public var data: [String: String]?

    /// Android notification-specific payload.
    public var notification: FCMAndroidNotification?

    // MARK: - Init

    public init(
        collapseKey:           String?                 = nil,
        priority:              Priority?               = nil,
        ttl:                   String?                 = nil,
        restrictedPackageName: String?                 = nil,
        data:                  [String: String]?       = nil,
        notification:          FCMAndroidNotification? = nil
    ) {
        self.collapseKey           = collapseKey
        self.priority              = priority
        self.ttl                   = ttl
        self.restrictedPackageName = restrictedPackageName
        self.data                  = data
        self.notification          = notification
    }

    private enum CodingKeys: String, CodingKey {
        case collapseKey           = "collapse_key"
        case priority, ttl
        case restrictedPackageName = "restricted_package_name"
        case data, notification
    }
}

// MARK: - TTL Convenience

extension FCMAndroidConfig {
    /// Builds a Google Duration string from a `TimeInterval` (seconds).
    public static func ttl(seconds: Double) -> String { "\(seconds)s" }
}

// MARK: -

/// Android notification payload.
public struct FCMAndroidNotification: Encodable, Sendable {

    public var title:       String?
    public var body:        String?
    public var icon:        String?
    /// Notification icon colour in `#RRGGBB` format.
    public var color:       String?
    public var sound:       String?
    /// Tag that collapses existing notifications with the same tag.
    public var tag:         String?
    public var imageURL:    String?
    public var clickAction: String?
    public var channelID:   String?

    public init(
        title:       String? = nil,
        body:        String? = nil,
        icon:        String? = nil,
        color:       String? = nil,
        sound:       String? = nil,
        tag:         String? = nil,
        imageURL:    String? = nil,
        clickAction: String? = nil,
        channelID:   String? = nil
    ) {
        self.title       = title
        self.body        = body
        self.icon        = icon
        self.color       = color
        self.sound       = sound
        self.tag         = tag
        self.imageURL    = imageURL
        self.clickAction = clickAction
        self.channelID   = channelID
    }

    private enum CodingKeys: String, CodingKey {
        case title, body, icon, color, sound, tag
        case imageURL    = "image"
        case clickAction = "click_action"
        case channelID   = "channel_id"
    }
}
