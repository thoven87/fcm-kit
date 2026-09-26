import Foundation

// MARK: - FCMLiveActivityEvent

/// The type of a Live Activity push event sent via FCM.
///
/// Use the static properties rather than raw strings so your code remains
/// compatible if Apple adds new event types in the future.
///
/// | Value | Effect |
/// |---|---|
/// | ``update`` | Replaces the Live Activity's `ContentState` with new data |
/// | ``end``    | Ends the activity; combine with ``FCMLiveActivityDismissalDate`` to control when the UI disappears |
public struct FCMLiveActivityEvent: RawRepresentable, Hashable, Sendable {

    /// The raw string sent in the `"event"` field of the APNs payload.
    public let rawValue: String

    /// Creates an event from a raw string value.
    ///
    /// Prefer the static constants (``update``, ``end``) over calling this directly.
    ///
    /// - Parameter rawValue: The APNs `event` string.
    public init(rawValue: String) { self.rawValue = rawValue }

    /// Update the content of a running Live Activity without ending it.
    public static let update = Self(rawValue: "update")

    /// End a running Live Activity.
    ///
    /// Combine with ``FCMLiveActivityDismissalDate`` to control how long the final
    /// state remains visible in the Dynamic Island and Lock Screen.
    public static let end    = Self(rawValue: "end")
}

// MARK: - FCMLiveActivityDismissalDate

/// Controls when a Live Activity's UI is dismissed after an ``FCMLiveActivityEvent/end`` event.
///
/// Pass one of the static factory values as the `dismissalDate` parameter of
/// ``FCMClient/sendLiveActivity(target:liveActivityToken:event:contentState:timestamp:dismissalDate:staleDate:alert:relevanceScore:apnsHeaders:)``.
public struct FCMLiveActivityDismissalDate: Hashable, Sendable {

    /// The UNIX timestamp (seconds since 1970) after which the UI is dismissed,
    /// or `nil` to let APNs use its default window.
    let dismissal: Int?

    /// Let APNs decide when to dismiss the Live Activity (typically up to 4 hours after ending).
    public static let none        = Self(dismissal: nil)

    /// Dismiss the Live Activity UI immediately when the end event is received.
    public static let immediately = Self(dismissal: 0)

    /// Dismiss at a specific UNIX timestamp.
    ///
    /// If the timestamp is already in the past when the notification arrives,
    /// the activity is dismissed immediately.
    ///
    /// - Parameter timeInterval: Seconds since 1970 (UTC).
    /// - Returns: A dismissal date set to the given timestamp.
    public static func timeIntervalSince1970InSeconds(_ timeInterval: Int) -> Self {
        Self(dismissal: timeInterval)
    }

    /// Dismiss at a specific `Date`.
    ///
    /// If the date is already in the past when the notification arrives,
    /// the activity is dismissed immediately.
    ///
    /// - Parameter date: The earliest date at which to dismiss the UI.
    /// - Returns: A dismissal date derived from `date`.
    public static func date(_ date: Date) -> Self {
        Self(dismissal: Int(date.timeIntervalSince1970))
    }
}

// MARK: - FCMLiveActivityAPS

/// The `aps` dictionary for a Live Activity **update** or **end** push.
///
/// This type is generic over `ContentState` — the `Encodable & Sendable` struct
/// that mirrors your app's `ActivityAttributes.ContentState` associated type.
///
/// You do not typically create this type directly; instead call
/// ``FCMClient/sendLiveActivity(target:liveActivityToken:event:contentState:timestamp:dismissalDate:staleDate:alert:relevanceScore:apnsHeaders:)``
/// which builds it internally.
///
/// If you need low-level control (e.g. to inspect the encoded payload before sending),
/// you can build one manually:
///
/// ```swift
/// struct GameScore: Encodable, Sendable {
///     let homeScore: Int
///     let awayScore: Int
/// }
///
/// let aps = FCMLiveActivityAPS(
///     event:        .update,
///     contentState: GameScore(homeScore: 3, awayScore: 1),
///     timestamp:    Int(Date().timeIntervalSince1970)
/// )
/// ```
public struct FCMLiveActivityAPS<ContentState: Encodable & Sendable>: Encodable, Sendable {

    /// The Live Activity event type (`"update"` or `"end"`).
    public var event: FCMLiveActivityEvent

    /// The updated dynamic content of the Live Activity.
    ///
    /// Must match the `ContentState` associated type of your `ActivityAttributes` conformer.
    public var contentState: ContentState

    /// UNIX timestamp (seconds since 1970) when this push was sent.
    ///
    /// APNs uses this to order updates when multiple pushes arrive out of order.
    public var timestamp: Int

    /// When to dismiss the Live Activity UI after an ``FCMLiveActivityEvent/end`` event.
    ///
    /// Defaults to ``FCMLiveActivityDismissalDate/none``, which lets APNs decide
    /// (typically up to 4 hours after the activity ends).
    public var dismissalDate: FCMLiveActivityDismissalDate

    /// UNIX timestamp after which the displayed content should be considered stale.
    ///
    /// The system may indicate to the user that the Live Activity data is out of date.
    public var staleDate: Int?

    /// An optional alert shown alongside the content update.
    ///
    /// Use this to notify the user of a significant state change (e.g. a goal scored).
    public var alert: FCMAPSAlert?

    /// A value in `[0, 1]` the system uses to sort Live Activities from your app
    /// when multiple are active simultaneously.
    public var relevanceScore: Double?

    /// Creates a Live Activity update/end APS payload.
    ///
    /// - Parameters:
    ///   - event:          ``FCMLiveActivityEvent/update`` or ``FCMLiveActivityEvent/end``.
    ///   - contentState:   The new content state to display.
    ///   - timestamp:      UNIX seconds when the push was generated. Defaults to now.
    ///   - dismissalDate:  When to remove the UI after `end` (default: ``FCMLiveActivityDismissalDate/none``).
    ///   - staleDate:      UNIX seconds after which the content is considered stale.
    ///   - alert:          Optional user-visible alert accompanying the update.
    ///   - relevanceScore: Sort key `[0, 1]` for multiple simultaneous activities.
    public init(
        event:          FCMLiveActivityEvent,
        contentState:   ContentState,
        timestamp:      Int,
        dismissalDate:  FCMLiveActivityDismissalDate = .none,
        staleDate:      Int?                         = nil,
        alert:          FCMAPSAlert?                 = nil,
        relevanceScore: Double?                      = nil
    ) {
        self.event          = event
        self.contentState   = contentState
        self.timestamp      = timestamp
        self.dismissalDate  = dismissalDate
        self.staleDate      = staleDate
        self.alert          = alert
        self.relevanceScore = relevanceScore
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(event.rawValue,               forKey: .event)
        try c.encode(contentState,                 forKey: .contentState)
        try c.encode(timestamp,                    forKey: .timestamp)
        try c.encodeIfPresent(dismissalDate.dismissal, forKey: .dismissalDate)
        try c.encodeIfPresent(staleDate,           forKey: .staleDate)
        try c.encodeIfPresent(alert,               forKey: .alert)
        try c.encodeIfPresent(relevanceScore,      forKey: .relevanceScore)
    }

    private enum CodingKeys: String, CodingKey {
        case event
        case contentState   = "content-state"
        case timestamp
        case dismissalDate  = "dismissal-date"
        case staleDate      = "stale-date"
        case alert
        case relevanceScore = "relevance-score"
    }
}

// MARK: - FCMLiveActivityStartAPS

/// The `aps` dictionary for a Live Activity **push-to-start** push.
///
/// Use this to remotely start a brand-new Live Activity on a device running iOS 17.2+.
/// Generic over both the static `Attributes` type and the initial `ContentState`.
///
/// You do not typically create this type directly; instead call
/// ``FCMClient/sendLiveActivity(target:liveActivityToken:contentState:attributesType:attributes:timestamp:staleDate:alert:relevanceScore:apnsHeaders:)``
/// which builds it internally.
///
/// ```swift
/// struct GameAttributes: Encodable, Sendable { let matchID: String }
/// struct GameScore: Encodable, Sendable { let home: Int; let away: Int }
///
/// let aps = FCMLiveActivityStartAPS(
///     contentState:   GameScore(home: 0, away: 0),
///     timestamp:      Int(Date().timeIntervalSince1970),
///     attributesType: "GameAttributes",
///     attributes:     GameAttributes(matchID: "final-2026")
/// )
/// ```
public struct FCMLiveActivityStartAPS<Attributes: Encodable & Sendable,
                                      ContentState: Encodable & Sendable>: Encodable, Sendable {

    // Always "start"; not exposed publicly.
    private let event: String = "start"

    /// The initial dynamic content state of the Live Activity.
    public var contentState: ContentState

    /// UNIX timestamp (seconds since 1970) when this push was sent.
    public var timestamp: Int

    /// The **exact Swift type name** of your `ActivityAttributes` conformer.
    ///
    /// ActivityKit uses this string to match the push to the correct attributes type
    /// registered in your app. It must match the type name precisely
    /// (e.g. `"GameAttributes"`, not `"MyApp.GameAttributes"`).
    public var attributesType: String

    /// The static, non-changing attributes for the new Live Activity.
    ///
    /// Must be the same type as `attributesType` identifies.
    public var attributes: Attributes

    /// UNIX seconds after which the initial content is considered stale.
    public var staleDate: Int?

    /// The alert shown to the user when the Live Activity is started.
    ///
    /// Required by Apple for push-to-start on iOS 16.2+.
    /// At minimum, supply a `title` or `body`.
    public var alert: FCMAPSAlert?

    /// A value in `[0, 1]` the system uses to sort Live Activities from your app.
    public var relevanceScore: Double?

    /// Creates a push-to-start APS payload.
    ///
    /// - Parameters:
    ///   - contentState:   The initial dynamic content of the activity.
    ///   - timestamp:      UNIX seconds when the push was generated. Defaults to now.
    ///   - attributesType: Exact Swift type name of the `ActivityAttributes` conformer.
    ///   - attributes:     Static attributes that define the activity.
    ///   - staleDate:      UNIX seconds after which the content is considered stale.
    ///   - alert:          User-visible alert for starting the activity.
    ///   - relevanceScore: Sort key `[0, 1]` for multiple simultaneous activities.
    public init(
        contentState:   ContentState,
        timestamp:      Int,
        attributesType: String,
        attributes:     Attributes,
        staleDate:      Int?         = nil,
        alert:          FCMAPSAlert? = nil,
        relevanceScore: Double?      = nil
    ) {
        self.contentState   = contentState
        self.timestamp      = timestamp
        self.attributesType = attributesType
        self.attributes     = attributes
        self.staleDate      = staleDate
        self.alert          = alert
        self.relevanceScore = relevanceScore
    }

    private enum CodingKeys: String, CodingKey {
        case event
        case contentState   = "content-state"
        case timestamp
        case attributesType = "attributes-type"
        case attributes
        case staleDate      = "stale-date"
        case alert
        case relevanceScore = "relevance-score"
    }
}
