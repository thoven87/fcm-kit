// MARK: - FCMAPNSConfig

/// Apple Push Notification service (APNS) overrides for an FCM message.
///
/// Use this to set APNs-specific headers, a fully custom APS payload,
/// FCM SDK options for iOS, and (for Live Activities) the push token.
///
/// - Note: FCM defaults `apns-expiration` to 30 days and `apns-priority` to 10
///   when those headers are not provided.
public struct FCMAPNSConfig: Encodable, Sendable {

    /// HTTP/2 request headers forwarded to APNs verbatim.
    ///
    /// Common keys:
    /// - `"apns-priority"`: `"10"` (immediate) or `"5"` (power-friendly)
    /// - `"apns-push-type"`: `"alert"`, `"background"`, `"liveactivity"`, etc.
    /// - `"apns-expiration"`: seconds since epoch; `"0"` to expire immediately
    public var headers: [String: String]?

    /// Raw APNs payload, including the `aps` dictionary and any custom keys.
    ///
    /// When set, overrides the message-level ``FCMNotification/title`` and
    /// ``FCMNotification/body``. Build this using ``FCMAPNSPayload`` and ``FCMAPS``.
    public var payload: FCMAPNSPayload?

    /// FCM SDK feature options for iOS (analytics label, image override).
    public var fcmOptions: FCMApnsOptions?

    /// Apple Live Activity token for this push.
    ///
    /// Accepts either a push token (from `activity.pushToken`) for update/end events,
    /// or a push-to-start token (from `Activity.pushToStartToken`) for start events.
    ///
    /// Build the `aps` payload using ``FCMLiveActivityAPS`` / ``FCMLiveActivityStartAPS``
    /// and pass it via ``FCMClient/sendLiveActivity(target:liveActivityToken:event:contentState:timestamp:dismissalDate:staleDate:alert:relevanceScore:apnsHeaders:)``
    /// rather than constructing this manually.
    public var liveActivityToken: String?

    /// Creates an APNS configuration.
    ///
    /// - Parameters:
    ///   - headers:           APNs HTTP/2 headers, e.g. `["apns-priority": "10"]`.
    ///   - payload:           APS payload wrapper built with ``FCMAPNSPayload``.
    ///   - fcmOptions:        FCM SDK options for iOS.
    ///   - liveActivityToken: Live Activity push token (update/end) or push-to-start token.
    public init(
        headers:           [String: String]? = nil,
        payload:           FCMAPNSPayload?   = nil,
        fcmOptions:        FCMApnsOptions?   = nil,
        liveActivityToken: String?           = nil
    ) {
        self.headers           = headers
        self.payload           = payload
        self.fcmOptions        = fcmOptions
        self.liveActivityToken = liveActivityToken
    }

    private enum CodingKeys: String, CodingKey {
        case headers, payload
        case fcmOptions        = "fcm_options"
        case liveActivityToken = "live_activity_token"
    }
}

// MARK: - FCMAPNSPayload

/// The APNs payload sent through FCM's `apns.payload` field.
///
/// This type models the `aps` dictionary only. FCM passes it verbatim to APNs.
/// If your app requires additional top-level custom keys alongside `aps`
/// (e.g. `{ "aps": {...}, "acme": "value" }`), encode the message manually
/// and pass it via ``FCMAPNSConfig/payload`` using a custom ``FCMAPNSPayload``
/// subtype or by omitting ``FCMAPNSConfig/payload`` and setting the raw keys
/// through a bespoke `Encodable` in a custom ``FCMJSONEncoder``.
public struct FCMAPNSPayload: Encodable, Sendable {

    /// The APNs `aps` dictionary.
    public var aps: FCMAPS

    /// Creates an APNs payload.
    ///
    /// - Parameter aps: The `aps` dictionary controlling system notification behaviour.
    public init(aps: FCMAPS) {
        self.aps = aps
    }
}

// MARK: - FCMAPSInterruptionLevel

/// Interruption level for an APNs notification (iOS 15+).
///
/// Controls how and when the system interrupts the user to display the notification.
/// See [Interruption levels](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel).
public enum FCMAPSInterruptionLevel: String, Encodable, Sendable {
    /// Delivered quietly without waking the screen or playing a sound.
    case passive       = "passive"
    /// Default behaviour — wakes the screen and plays the configured sound.
    case active        = "active"
    /// High-priority delivery that can break through Focus modes.
    case timeSensitive = "time-sensitive"
    /// Highest priority; bypasses Do Not Disturb and Focus. Requires a special entitlement.
    case critical      = "critical"
}

// MARK: - FCMAPS

/// The `aps` dictionary of an APNs payload.
///
/// `contentAvailable` and `mutableContent` are `Double?` so that passing `1`
/// serialises to the JSON integer `1` — exactly what APNs requires on the wire.
/// A JSON boolean `true` is a different token and is not accepted by APNs.
public struct FCMAPS: Encodable, Sendable {

    /// The alert displayed to the user.
    public var alert: FCMAPSAlert?

    /// Badge count to display on the app icon. Set to `0` to remove the badge.
    public var badge: Int?

    /// Sound name, or `"default"` for the system sound.
    public var sound: String?

    /// Pass `1` to deliver a background notification without user-visible UI.
    public var contentAvailable: Double?

    /// Pass `1` to allow the Notification Service Extension to modify the payload.
    public var mutableContent: Double?

    /// The notification's category identifier, used with `UNNotificationCategory`.
    public var category: String?

    /// Groups related notifications under the same thread identifier.
    public var threadID: String?

    /// Interruption level controlling when the system presents the notification (iOS 15+).
    public var interruptionLevel: FCMAPSInterruptionLevel?

    /// Relevance score in [0, 1] used to order notifications from your app (iOS 15+).
    ///
    /// Higher values are surfaced higher in Notification Summary.
    public var relevanceScore: Double?

    /// The identifier of the Notification Content Extension to use for custom UI.
    public var targetContentID: String?

    /// Grouping key used with Notification Content Extensions for collapsing (iOS 16+).
    public var filterCriteria: String?

    /// Creates an `aps` dictionary.
    ///
    /// - Parameters:
    ///   - alert:              The visible alert content.
    ///   - badge:              App icon badge count.
    ///   - sound:              Sound file name, or `"default"`.
    ///   - contentAvailable:   Pass `1` for background delivery.
    ///   - mutableContent:     Pass `1` to allow payload modification by a Notification Service Extension.
    ///   - category:           `UNNotificationCategory` identifier.
    ///   - threadID:           Groups notifications in the system UI.
    ///   - interruptionLevel:  Delivery urgency (iOS 15+).
    ///   - relevanceScore:     Notification Summary ordering score (iOS 15+).
    ///   - targetContentID:    Notification Content Extension identifier.
    ///   - filterCriteria:     Collapse key for Notification Content Extensions (iOS 16+).
    public init(
        alert:             FCMAPSAlert?             = nil,
        badge:             Int?                     = nil,
        sound:             String?                  = nil,
        contentAvailable:  Double?                  = nil,
        mutableContent:    Double?                  = nil,
        category:          String?                  = nil,
        threadID:          String?                  = nil,
        interruptionLevel: FCMAPSInterruptionLevel? = nil,
        relevanceScore:    Double?                  = nil,
        targetContentID:   String?                  = nil,
        filterCriteria:    String?                  = nil
    ) {
        self.alert             = alert
        self.badge             = badge
        self.sound             = sound
        self.contentAvailable  = contentAvailable
        self.mutableContent    = mutableContent
        self.category          = category
        self.threadID          = threadID
        self.interruptionLevel = interruptionLevel
        self.relevanceScore    = relevanceScore
        self.targetContentID   = targetContentID
        self.filterCriteria    = filterCriteria
    }

    private enum CodingKeys: String, CodingKey {
        case alert, badge, sound, category
        case contentAvailable  = "content-available"
        case mutableContent    = "mutable-content"
        case threadID          = "thread-id"
        case interruptionLevel = "interruption-level"
        case relevanceScore    = "relevance-score"
        case targetContentID   = "target-content-id"
        case filterCriteria    = "filter-criteria"
    }
}

// MARK: - FCMAPSAlert

/// The `alert` dictionary inside an ``FCMAPS`` payload.
///
/// Supports both raw strings and localisation keys.
/// For localised strings supply the appropriate `*LocKey` / `*LocArgs` fields
/// and leave the raw `title` / `body` fields `nil`.
public struct FCMAPSAlert: Encodable, Sendable {

    /// Raw notification title (shown directly; not localised).
    public var title: String?

    /// Raw notification subtitle.
    public var subtitle: String?

    /// Raw notification body text.
    public var body: String?

    // MARK: Localisation

    /// Key in `Localizable.strings` used to localise the title.
    public var titleLocKey: String?

    /// Substitution values for `%@` placeholders in ``titleLocKey``.
    public var titleLocArgs: [String]?

    /// Key in `Localizable.strings` used to localise the body.
    public var locKey: String?

    /// Substitution values for `%@` placeholders in ``locKey``.
    public var locArgs: [String]?

    /// Key for a localised dismiss-button title in the app's strings file.
    public var actionLocKey: String?

    /// Name of an image in the app bundle to use as the launch image.
    public var launchImage: String?

    /// Creates an alert dictionary.
    ///
    /// - Parameters:
    ///   - title:        Raw title string.
    ///   - subtitle:     Raw subtitle string.
    ///   - body:         Raw body string.
    ///   - titleLocKey:  Localisation key for the title.
    ///   - titleLocArgs: Substitution values for `titleLocKey`.
    ///   - locKey:       Localisation key for the body.
    ///   - locArgs:      Substitution values for `locKey`.
    ///   - actionLocKey: Localisation key for the dismiss-action button.
    ///   - launchImage:  Launch image name from the app bundle.
    public init(
        title:        String?   = nil,
        subtitle:     String?   = nil,
        body:         String?   = nil,
        titleLocKey:  String?   = nil,
        titleLocArgs: [String]? = nil,
        locKey:       String?   = nil,
        locArgs:      [String]? = nil,
        actionLocKey: String?   = nil,
        launchImage:  String?   = nil
    ) {
        self.title        = title
        self.subtitle     = subtitle
        self.body         = body
        self.titleLocKey  = titleLocKey
        self.titleLocArgs = titleLocArgs
        self.locKey       = locKey
        self.locArgs      = locArgs
        self.actionLocKey = actionLocKey
        self.launchImage  = launchImage
    }

    private enum CodingKeys: String, CodingKey {
        case title, subtitle, body
        case titleLocKey  = "title-loc-key"
        case titleLocArgs = "title-loc-args"
        case locKey       = "loc-key"
        case locArgs      = "loc-args"
        case actionLocKey = "action-loc-key"
        case launchImage  = "launch-image"
    }
}
