/// Cross-platform notification template displayed on all target platforms.
///
/// Use platform-specific configs (``FCMAPNSConfig``, ``FCMAndroidConfig``,
/// ``FCMWebpushConfig``) to override or extend these values per platform.
public struct FCMNotification: Encodable, Sendable {

    /// The notification title displayed in the system tray or banner.
    public var title: String?

    /// The body text of the notification.
    public var body: String?

    /// URL of an image downloaded and displayed inside the notification.
    ///
    /// JPEG, PNG and BMP have full cross-platform support.
    /// Animated GIF and video work on iOS only.
    /// Android enforces a 1 MB image size limit.
    public var imageURL: String?

    /// Creates a cross-platform notification.
    ///
    /// - Parameters:
    ///   - title:    Notification title. Overridden per-platform if a platform config is set.
    ///   - body:     Notification body text. Overridden per-platform if a platform config is set.
    ///   - imageURL: URL of an image to display inside the notification.
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
