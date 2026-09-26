/// Cross-platform notification that appears in all device types.
///
/// For platform-specific overrides use ``FCMAndroidConfig/notification``,
/// ``FCMAPNSConfig``, or ``FCMWebpushConfig/notification``.
public struct FCMNotification: Encodable, Sendable {

    /// Title displayed in the notification.
    public var title: String?

    /// Body text of the notification.
    public var body: String?

    /// URL of an image shown in the notification.
    public var imageURL: String?

    public init(
        title:    String? = nil,
        body:     String? = nil,
        imageURL: String? = nil
    ) {
        self.title    = title
        self.body     = body
        self.imageURL = imageURL
    }

    private enum CodingKeys: String, CodingKey {
        case title, body
        case imageURL = "image"
    }
}
