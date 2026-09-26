import Foundation
import AsyncHTTPClient
import NIOCore

// MARK: - Live Activity sends

extension FCMClient {

    // MARK: - Update / End

    /// Sends a Live Activity **update** or **end** push via FCM.
    ///
    /// Use this to update an already-running Live Activity's content state,
    /// or to end it when the activity is finished.
    ///
    /// ```swift
    /// struct GameScore: Encodable, Sendable { let home: Int; let away: Int }
    ///
    /// // Update
    /// try await client.sendLiveActivity(
    ///     target:            .fid(deviceToken),
    ///     liveActivityToken: activity.pushToken,
    ///     event:             .update,
    ///     contentState:      GameScore(home: 3, away: 1),
    ///     timestamp:         Int(Date().timeIntervalSince1970)
    /// )
    ///
    /// // End with immediate dismissal
    /// try await client.sendLiveActivity(
    ///     target:            .fid(deviceToken),
    ///     liveActivityToken: activity.pushToken,
    ///     event:             .end,
    ///     contentState:      GameScore(home: 3, away: 1),
    ///     timestamp:         Int(Date().timeIntervalSince1970),
    ///     dismissalDate:     .immediately
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - target:            FCM delivery target (`.fid`, `.topic`, or `.condition`).
    ///   - liveActivityToken: The push token from `activity.pushToken`.
    ///   - event:             ``FCMLiveActivityEvent/update`` or ``FCMLiveActivityEvent/end``.
    ///   - contentState:      Updated content state matching your `ActivityAttributes.ContentState`.
    ///   - timestamp:         UNIX timestamp (seconds) — defaults to now.
    ///   - dismissalDate:     When to dismiss the UI after an `end` event (default: `.none`).
    ///   - staleDate:         UNIX timestamp after which content is considered stale.
    ///   - alert:             Optional alert shown alongside the update.
    ///   - relevanceScore:    System sort key for Live Activities from your app.
    ///   - apnsHeaders:       Extra APNs HTTP/2 headers, e.g. `["apns-priority": "10"]`.
    /// - Returns: The FCM message name, e.g. `"projects/my-project/messages/0:…"`.
    /// - Throws: ``FCMError/serverError(status:code:message:)`` for FCM-level errors,
    ///   ``FCMError/tokenGenerationFailed(_:)`` if OAuth token refresh fails,
    ///   or ``FCMError/encodingFailed`` if the content state cannot be serialised.
    @discardableResult
    public func sendLiveActivity<ContentState: Encodable & Sendable>(
        target:            FCMMessage.Target,
        liveActivityToken: String,
        event:             FCMLiveActivityEvent,
        contentState:      ContentState,
        timestamp:         Int                       = Int(Date().timeIntervalSince1970),
        dismissalDate:     FCMLiveActivityDismissalDate = .none,
        staleDate:         Int?                      = nil,
        alert:             FCMAPSAlert?              = nil,
        relevanceScore:    Double?                   = nil,
        apnsHeaders:       [String: String]?         = nil
    ) async throws -> String {
        let aps = FCMLiveActivityAPS(
            event:          event,
            contentState:   contentState,
            timestamp:      timestamp,
            dismissalDate:  dismissalDate,
            staleDate:      staleDate,
            alert:          alert,
            relevanceScore: relevanceScore
        )
        let tok = try await tokenProvider.validToken()
        return try await executeLiveActivity(
            token: tok, target: target,
            liveActivityToken: liveActivityToken, aps: aps,
            headers: apnsHeaders
        )
    }

    // MARK: - Start (push-to-start)

    /// Starts a new Live Activity remotely (push-to-start).
    ///
    /// This overload is distinguished from the update/end variant by the presence of
    /// `attributesType:` and `attributes:` parameters. Requires iOS 17.2+ and the
    /// ActivityKit push notifications entitlement.
    ///
    /// ```swift
    /// struct GameAttributes: Encodable, Sendable { let matchID: String }
    /// struct GameScore: Encodable, Sendable { let home: Int; let away: Int }
    ///
    /// try await client.sendLiveActivity(
    ///     target:            .fid(deviceToken),
    ///     liveActivityToken: activity.pushToStartToken,
    ///     contentState:      GameScore(home: 0, away: 0),
    ///     attributesType:    "GameAttributes",
    ///     attributes:        GameAttributes(matchID: "final-2026"),
    ///     timestamp:         Int(Date().timeIntervalSince1970),
    ///     alert:             FCMAPSAlert(title: "Match started!", body: "Tap to follow live.")
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - target:            FCM delivery target.
    ///   - liveActivityToken: The push-to-start token from `Activity.pushToStartToken`.
    ///   - contentState:      Initial content state.
    ///   - attributesType:    Exact Swift type name of your `ActivityAttributes` conformer.
    ///   - attributes:        Static attributes for the new activity.
    ///   - timestamp:         UNIX timestamp (seconds) — defaults to now.
    ///   - staleDate:         UNIX timestamp after which content is stale.
    ///   - alert:             Alert shown when starting the Live Activity.
    ///   - relevanceScore:    System sort key.
    ///   - apnsHeaders:       Extra APNs HTTP/2 headers.
    /// - Returns: The FCM message name, e.g. `"projects/my-project/messages/0:…"`.
    /// - Throws: ``FCMError`` on network or server failure.
    /// - Important: Requires the **ActivityKit push notifications** entitlement and iOS 17.2+.
    @discardableResult
    public func sendLiveActivity<Attributes: Encodable & Sendable,
                                  ContentState: Encodable & Sendable>(
        target:            FCMMessage.Target,
        liveActivityToken: String,
        contentState:      ContentState,
        attributesType:    String,
        attributes:        Attributes,
        timestamp:         Int               = Int(Date().timeIntervalSince1970),
        staleDate:         Int?              = nil,
        alert:             FCMAPSAlert?      = nil,
        relevanceScore:    Double?           = nil,
        apnsHeaders:       [String: String]? = nil
    ) async throws -> String {
        let aps = FCMLiveActivityStartAPS(
            contentState:   contentState,
            timestamp:      timestamp,
            attributesType: attributesType,
            attributes:     attributes,
            staleDate:      staleDate,
            alert:          alert,
            relevanceScore: relevanceScore
        )
        let tok = try await tokenProvider.validToken()
        return try await executeLiveActivity(
            token: tok, target: target,
            liveActivityToken: liveActivityToken, aps: aps,
            headers: apnsHeaders
        )
    }

    // MARK: - Private

    /// Encodes and sends a Live Activity FCM message for any APS type.
    private func executeLiveActivity<APS: Encodable & Sendable>(
        token:             String,
        target:            FCMMessage.Target,
        liveActivityToken: String,
        aps:               APS,
        headers:           [String: String]?
    ) async throws -> String {
        let request = LARequest(
            message: LAMessage(
                target: target,
                apns: LAAPNSConfig(
                    headers:           headers,
                    liveActivityToken: liveActivityToken,
                    aps:               aps
                )
            )
        )

        var buffer = byteBufferAllocator.buffer(capacity: 512)
        try encode(request, into: &buffer)

        var req = HTTPClientRequest(url: sendURL)
        req.method = .POST
        req.headers.add(name: "Authorization", value: "Bearer \(token)")
        req.headers.add(name: "Content-Type",  value: "application/json; charset=utf-8")
        req.body = .bytes(buffer)

        let response = try await httpClient.execute(req, timeout: configuration.requestTimeoutAmount)
        return try await parseSendResponse(response)
    }
}

// MARK: - Private wire types
//
// These mirror the FCM message hierarchy but carry a generic APS type,
// allowing content-state and attributes to flow through as typed generics.

private struct LARequest<APS: Encodable & Sendable>: Encodable, Sendable {
    let validateOnly: Bool? = nil
    let message:      LAMessage<APS>

    private enum CodingKeys: String, CodingKey {
        case validateOnly = "validate_only"
        case message
    }
}

private struct LAMessage<APS: Encodable & Sendable>: Encodable, Sendable {
    let target: FCMMessage.Target
    let apns:   LAAPNSConfig<APS>

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch target {
        case .fid(let v):       try c.encode(v, forKey: .fid)
        case .topic(let v):     try c.encode(v, forKey: .topic)
        case .condition(let v): try c.encode(v, forKey: .condition)
        }
        try c.encode(apns, forKey: .apns)
    }

    private enum CodingKeys: String, CodingKey {
        case fid, topic, condition, apns
    }
}

private struct LAAPNSConfig<APS: Encodable & Sendable>: Encodable, Sendable {
    let headers:           [String: String]?
    let liveActivityToken: String
    let aps:               APS

    /// Encodes to the FCM `ApnsConfig` shape:
    /// `{ headers?, live_activity_token, payload: { aps: <APS> } }`
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(headers,           forKey: .headers)
        try c.encode(liveActivityToken,           forKey: .liveActivityToken)
        var payloadC = c.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
        try payloadC.encode(aps,                  forKey: .aps)
    }

    private enum CodingKeys: String, CodingKey {
        case headers, payload
        case liveActivityToken = "live_activity_token"
    }
    private enum PayloadKeys: String, CodingKey { case aps }
}
