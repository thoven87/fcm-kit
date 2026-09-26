/// Android-specific message configuration.
public struct FCMAndroidConfig: Encodable, Sendable {

    // MARK: - Message Priority

    /// FCM delivery priority. Controls when the message is delivered, not how it is displayed.
    ///
    /// For display priority, see ``FCMAndroidNotification/notificationPriority``.
    public enum Priority: String, Encodable, Sendable {
        case normal = "NORMAL"
        case high   = "HIGH"
    }

    // MARK: - Properties

    /// Identifies a group of messages that can be collapsed, so only the last is delivered. Max 4 keys.
    public var collapseKey: String?

    /// FCM delivery priority.
    public var priority: Priority?

    /// How long (in seconds) FCM stores the message if the device is offline. Max 4 weeks.
    ///
    /// Use ``ttl(seconds:)`` to build the required Duration string, e.g. `"3.5s"`.
    public var ttl: String?

    /// Package name the registration token must match in order to receive the message.
    public var restrictedPackageName: String?

    /// Arbitrary key/value data. Overrides the message-level ``FCMMessage/data``.
    public var data: [String: String]?

    /// Android notification payload.
    public var notification: FCMAndroidNotification?

    /// FCM SDK feature options (analytics label, etc.).
    public var fcmOptions: FCMAndroidOptions?

    /// Deliver the message while the device is in direct boot mode.
    public var directBootOk: Bool?

    /// Deliver the message while the device is in bandwidth-constrained mode.
    public var bandwidthConstrainedOk: Bool?

    /// Deliver the message while the device is connected over a restricted satellite network.
    public var restrictedSatelliteOk: Bool?

    // MARK: - Init

    public init(
        collapseKey:            String?                 = nil,
        priority:               Priority?               = nil,
        ttl:                    String?                 = nil,
        restrictedPackageName:  String?                 = nil,
        data:                   [String: String]?       = nil,
        notification:           FCMAndroidNotification? = nil,
        fcmOptions:             FCMAndroidOptions?      = nil,
        directBootOk:           Bool?                   = nil,
        bandwidthConstrainedOk: Bool?                   = nil,
        restrictedSatelliteOk:  Bool?                   = nil
    ) {
        self.collapseKey            = collapseKey
        self.priority               = priority
        self.ttl                    = ttl
        self.restrictedPackageName  = restrictedPackageName
        self.data                   = data
        self.notification           = notification
        self.fcmOptions             = fcmOptions
        self.directBootOk           = directBootOk
        self.bandwidthConstrainedOk = bandwidthConstrainedOk
        self.restrictedSatelliteOk  = restrictedSatelliteOk
    }

    private enum CodingKeys: String, CodingKey {
        case collapseKey            = "collapse_key"
        case priority, ttl
        case restrictedPackageName  = "restricted_package_name"
        case data, notification
        case fcmOptions             = "fcm_options"
        case directBootOk           = "direct_boot_ok"
        case bandwidthConstrainedOk = "bandwidth_constrained_ok"
        case restrictedSatelliteOk  = "restricted_satellite_ok"
    }
}

// MARK: - TTL Convenience

extension FCMAndroidConfig {
    /// Builds a Google Duration string from a `TimeInterval` in seconds, e.g. `"3.5s"`.
    public static func ttl(seconds: Double) -> String { "\(seconds)s" }
}
