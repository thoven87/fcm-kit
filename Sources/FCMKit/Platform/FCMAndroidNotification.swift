/// Android notification payload.
///
/// Fields set here override any values set in the base ``FCMNotification``.
public struct FCMAndroidNotification: Encodable, Sendable {

    // MARK: - Basic

    public var title:       String?
    public var body:        String?
    public var icon:        String?
    /// Notification icon colour in `#RRGGBB` format.
    public var color:       String?
    /// Sound file name in `/res/raw/`, or `"default"` for the system sound.
    public var sound:       String?
    /// Collapses existing notifications with the same tag.
    public var tag:         String?
    public var imageURL:    String?
    public var clickAction: String?
    /// Android notification channel ID (required on Android 8.0+).
    public var channelID:   String?

    // MARK: - Localization

    /// Body string key in the app's string resources.
    public var bodyLocKey:   String?
    public var bodyLocArgs:  [String]?
    /// Title string key in the app's string resources.
    public var titleLocKey:  String?
    public var titleLocArgs: [String]?

    // MARK: - Display

    /// Text shown in the status bar when the notification first arrives (pre-Lollipop).
    public var ticker: String?
    /// Keep the notification in the tray after the user taps it.
    public var sticky: Bool?
    /// RFC 3339 timestamp of the event that triggered the notification. Used for ordering.
    public var eventTime: String?
    /// Restrict to the current device only — do not bridge to wearables.
    public var localOnly: Bool?
    /// On-device display priority (Android 7.1 and earlier; use channel importance on 8.0+).
    public var notificationPriority: FCMNotificationPriority?
    public var defaultSound: Bool?
    public var defaultVibrateTimings: Bool?
    public var defaultLightSettings: Bool?
    /// Array of Google Duration strings defining the vibration pattern, e.g. `["0s", "0.5s", "0.5s"]`.
    public var vibrateTimings: [String]?
    public var visibility: FCMVisibility?
    /// Badge count for launcher icon badging.
    public var notificationCount: Int?
    public var lightSettings: FCMLightSettings?
    public var proxy: FCMProxy?

    // MARK: - Init

    public init(
        title:                   String?                  = nil,
        body:                    String?                  = nil,
        icon:                    String?                  = nil,
        color:                   String?                  = nil,
        sound:                   String?                  = nil,
        tag:                     String?                  = nil,
        imageURL:                String?                  = nil,
        clickAction:             String?                  = nil,
        channelID:               String?                  = nil,
        bodyLocKey:              String?                  = nil,
        bodyLocArgs:             [String]?                = nil,
        titleLocKey:             String?                  = nil,
        titleLocArgs:            [String]?                = nil,
        ticker:                  String?                  = nil,
        sticky:                  Bool?                    = nil,
        eventTime:               String?                  = nil,
        localOnly:               Bool?                    = nil,
        notificationPriority:    FCMNotificationPriority? = nil,
        defaultSound:            Bool?                    = nil,
        defaultVibrateTimings:   Bool?                    = nil,
        defaultLightSettings:    Bool?                    = nil,
        vibrateTimings:          [String]?                = nil,
        visibility:              FCMVisibility?           = nil,
        notificationCount:       Int?                     = nil,
        lightSettings:           FCMLightSettings?        = nil,
        proxy:                   FCMProxy?                = nil
    ) {
        self.title                 = title
        self.body                  = body
        self.icon                  = icon
        self.color                 = color
        self.sound                 = sound
        self.tag                   = tag
        self.imageURL              = imageURL
        self.clickAction           = clickAction
        self.channelID             = channelID
        self.bodyLocKey            = bodyLocKey
        self.bodyLocArgs           = bodyLocArgs
        self.titleLocKey           = titleLocKey
        self.titleLocArgs          = titleLocArgs
        self.ticker                = ticker
        self.sticky                = sticky
        self.eventTime             = eventTime
        self.localOnly             = localOnly
        self.notificationPriority  = notificationPriority
        self.defaultSound          = defaultSound
        self.defaultVibrateTimings = defaultVibrateTimings
        self.defaultLightSettings  = defaultLightSettings
        self.vibrateTimings        = vibrateTimings
        self.visibility            = visibility
        self.notificationCount     = notificationCount
        self.lightSettings         = lightSettings
        self.proxy                 = proxy
    }

    private enum CodingKeys: String, CodingKey {
        case title, body, icon, color, sound, tag
        case imageURL             = "image"
        case clickAction          = "click_action"
        case channelID            = "channel_id"
        case bodyLocKey           = "body_loc_key"
        case bodyLocArgs          = "body_loc_args"
        case titleLocKey          = "title_loc_key"
        case titleLocArgs         = "title_loc_args"
        case ticker, sticky
        case eventTime            = "event_time"
        case localOnly            = "local_only"
        case notificationPriority = "notification_priority"
        case defaultSound         = "default_sound"
        case defaultVibrateTimings = "default_vibrate_timings"
        case defaultLightSettings = "default_light_settings"
        case vibrateTimings       = "vibrate_timings"
        case visibility
        case notificationCount    = "notification_count"
        case lightSettings        = "light_settings"
        case proxy
    }
}
