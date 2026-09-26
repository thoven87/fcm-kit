// MARK: - FCMNotificationPriority

/// On-device display priority of an Android notification (Android 7.1 / API 25 and earlier).
///
/// On Android 8.0+ (API 26+) channel importance supersedes this value.
/// This is distinct from ``FCMAndroidConfig/Priority``, which controls FCM delivery priority.
public enum FCMNotificationPriority: String, Encodable, Sendable {
    /// System default priority; equivalent to ``default``.
    case unspecified = "PRIORITY_UNSPECIFIED"
    /// Lowest priority. May not be shown except in notification logs.
    case min         = "PRIORITY_MIN"
    /// Lower than default; may be shown smaller or lower in the list.
    case low         = "PRIORITY_LOW"
    /// Standard priority. Use for notifications that don't require immediate attention.
    case `default`   = "PRIORITY_DEFAULT"
    /// Higher than default; shown more prominently.
    case high        = "PRIORITY_HIGH"
    /// Highest priority; requires the user's immediate attention.
    case max         = "PRIORITY_MAX"
}

// MARK: - FCMVisibility

/// Lock-screen visibility of an Android notification.
public enum FCMVisibility: String, Encodable, Sendable {
    /// Default to ``private``.
    case unspecified = "VISIBILITY_UNSPECIFIED"
    /// Show the notification on all lock screens, concealing sensitive content on secure screens.
    case `private`   = "PRIVATE"
    /// Show the notification in its entirety on all lock screens.
    case `public`    = "PUBLIC"
    /// Do not reveal any part of this notification on a secure lock screen.
    case secret      = "SECRET"
}

// MARK: - FCMProxy

/// Controls when FCM may proxy an Android notification through Google Play services.
public enum FCMProxy: String, Encodable, Sendable {
    /// Default — equivalent to ``ifPriorityLowered``.
    case unspecified       = "PROXY_UNSPECIFIED"
    /// Always try to proxy this notification.
    case allow             = "ALLOW"
    /// Never proxy this notification.
    case deny              = "DENY"
    /// Proxy only if FCM lowered the message priority from `HIGH` to `NORMAL` on the device.
    case ifPriorityLowered = "IF_PRIORITY_LOWERED"
}

// MARK: - FCMLightSettings

/// Settings to control the notification LED on Android devices that have one.
public struct FCMLightSettings: Encodable, Sendable {

    /// LED colour.
    public var color: FCMColor

    /// Duration the LED stays **on** per blink cycle.
    ///
    /// Google Duration string format, e.g. `"0.5s"`.
    public var lightOnDuration: String

    /// Duration the LED stays **off** per blink cycle.
    ///
    /// Google Duration string format, e.g. `"0.5s"`.
    public var lightOffDuration: String

    /// Creates LED light settings.
    ///
    /// - Parameters:
    ///   - color:            LED colour in [0, 1] RGBA space.
    ///   - lightOnDuration:  On-phase duration, e.g. `"0.5s"`.
    ///   - lightOffDuration: Off-phase duration, e.g. `"0.5s"`.
    public init(color: FCMColor, lightOnDuration: String, lightOffDuration: String) {
        self.color            = color
        self.lightOnDuration  = lightOnDuration
        self.lightOffDuration = lightOffDuration
    }

    private enum CodingKeys: String, CodingKey {
        case color
        case lightOnDuration  = "light_on_duration"
        case lightOffDuration = "light_off_duration"
    }
}

// MARK: - FCMColor

/// An RGBA colour with components in the `[0, 1]` range, as defined by `google.type.Color`.
///
/// Example — red at full opacity:
/// ```swift
/// FCMColor(red: 1.0, green: 0.0, blue: 0.0)
/// ```
public struct FCMColor: Encodable, Sendable {

    /// Red channel, `[0, 1]`.
    public var red: Float

    /// Green channel, `[0, 1]`.
    public var green: Float

    /// Blue channel, `[0, 1]`.
    public var blue: Float

    /// Opacity, `[0, 1]`. When `nil`, the colour is fully opaque.
    public var alpha: Float?

    /// Creates an RGBA colour.
    ///
    /// - Parameters:
    ///   - red:   Red channel, `[0, 1]`.
    ///   - green: Green channel, `[0, 1]`.
    ///   - blue:  Blue channel, `[0, 1]`.
    ///   - alpha: Opacity, `[0, 1]`. Default `nil` (fully opaque).
    public init(red: Float, green: Float, blue: Float, alpha: Float? = nil) {
        self.red   = red
        self.green = green
        self.blue  = blue
        self.alpha = alpha
    }
}
