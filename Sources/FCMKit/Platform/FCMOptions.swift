// MARK: - Message-level

/// Cross-platform FCM SDK feature options, applied to the message as a whole.
///
/// Set these to associate the message with an analytics label that appears
/// in the Firebase console.
public struct FCMOptions: Encodable, Sendable {

    /// Label associated with this message's analytics data.
    ///
    /// Must match the regex `[a-zA-Z0-9_-]{1,50}`.
    public var analyticsLabel: String?

    /// Creates cross-platform FCM options.
    ///
    /// - Parameter analyticsLabel: Analytics label for Firebase console reporting.
    public init(analyticsLabel: String? = nil) {
        self.analyticsLabel = analyticsLabel
    }

    private enum CodingKeys: String, CodingKey {
        case analyticsLabel = "analytics_label"
    }
}

// MARK: - Android

/// FCM SDK feature options specific to Android messages.
public struct FCMAndroidOptions: Encodable, Sendable {

    /// Label associated with this message's analytics data.
    public var analyticsLabel: String?

    /// Creates Android FCM options.
    ///
    /// - Parameter analyticsLabel: Analytics label for Firebase console reporting.
    public init(analyticsLabel: String? = nil) {
        self.analyticsLabel = analyticsLabel
    }

    private enum CodingKeys: String, CodingKey {
        case analyticsLabel = "analytics_label"
    }
}

// MARK: - Web Push

/// FCM SDK feature options specific to Web Push messages.
public struct FCMWebpushOptions: Encodable, Sendable {

    /// The URL to open when the user clicks the notification. Must use HTTPS.
    public var link: String?

    /// Label associated with this message's analytics data.
    public var analyticsLabel: String?

    /// Creates Web Push FCM options.
    ///
    /// - Parameters:
    ///   - link:           Deep-link URL opened on notification tap.
    ///   - analyticsLabel: Analytics label for Firebase console reporting.
    public init(link: String? = nil, analyticsLabel: String? = nil) {
        self.link           = link
        self.analyticsLabel = analyticsLabel
    }

    private enum CodingKeys: String, CodingKey {
        case link
        case analyticsLabel = "analytics_label"
    }
}

// MARK: - APNS

/// FCM SDK feature options specific to iOS / APNS messages.
public struct FCMApnsOptions: Encodable, Sendable {

    /// Label associated with this message's analytics data.
    public var analyticsLabel: String?

    /// URL of an image to display in the notification,
    /// overriding the message-level ``FCMNotification/imageURL``.
    public var imageURL: String?

    /// Creates APNS FCM options.
    ///
    /// - Parameters:
    ///   - analyticsLabel: Analytics label for Firebase console reporting.
    ///   - imageURL:       Notification image URL, overrides the message-level image.
    public init(analyticsLabel: String? = nil, imageURL: String? = nil) {
        self.analyticsLabel = analyticsLabel
        self.imageURL       = imageURL
    }

    private enum CodingKeys: String, CodingKey {
        case analyticsLabel = "analytics_label"
        case imageURL       = "image"
    }
}
