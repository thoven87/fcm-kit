import Testing
import Foundation
import FCMKitTestSupport
@testable import FCMKit

// MARK: - ServiceAccount

@Suite("ServiceAccount")
struct ServiceAccountTests {

    let validJSON = """
    {
        "type": "service_account",
        "project_id": "my-project",
        "private_key_id": "key-abc-123",
        "private_key": "-----BEGIN RSA PRIVATE KEY-----\\nMIIBOgIBAAJBALRiMLAHudeSA/xKl1oFnTkDJACEGCWBSJYMXKMkGGpCZCiIPaGI\\n-----END RSA PRIVATE KEY-----",
        "client_email": "firebase@my-project.iam.gserviceaccount.com",
        "token_uri": "https://oauth2.googleapis.com/token"
    }
    """

    @Test("decodes required fields")
    func decodesFields() throws {
        let account = try ServiceAccount.load(from: Data(validJSON.utf8))
        #expect(account.projectID    == "my-project")
        #expect(account.privateKeyID == "key-abc-123")
        #expect(account.clientEmail  == "firebase@my-project.iam.gserviceaccount.com")
        #expect(account.tokenURI     == "https://oauth2.googleapis.com/token")
    }

    @Test("throws on invalid JSON")
    func throwsOnInvalidJSON() {
        #expect(throws: FCMError.self) {
            try ServiceAccount.load(from: Data("not-json".utf8))
        }
    }

    @Test("load(fromJSON:) accepts a raw string")
    func loadFromJSONString() throws {
        let account = try ServiceAccount.load(fromJSON: validJSON)
        #expect(account.projectID == "my-project")
    }
}

// MARK: - FCMMessage encoding

@Suite("FCMMessage encoding")
struct FCMMessageEncodingTests {

    private struct DecodedMessage: Decodable {
        let fid:       String?
        let topic:     String?
        let condition: String?

        struct Notification: Decodable {
            let title: String?
            let body:  String?
            let image: String?
        }
        let notification: Notification?
        let data:         [String: String]?
    }

    private func decoded(_ msg: FCMMessage) throws -> DecodedMessage {
        let data = try JSONEncoder().encode(msg)
        return try JSONDecoder().decode(DecodedMessage.self, from: data)
    }

    @Test("fid target sets only fid field")
    func fidTarget() throws {
        let msg = FCMMessage(target: .fid("tok-xyz"))
        let d   = try decoded(msg)
        #expect(d.fid       == "tok-xyz")
        #expect(d.topic     == nil)
        #expect(d.condition == nil)
    }

    @Test("topic target sets only topic field")
    func topicTarget() throws {
        let msg = FCMMessage(target: .topic("breaking-news"))
        let d   = try decoded(msg)
        #expect(d.topic     == "breaking-news")
        #expect(d.fid       == nil)
        #expect(d.condition == nil)
    }

    @Test("condition target sets only condition field")
    func conditionTarget() throws {
        let msg = FCMMessage(target: .condition("'sport' in topics"))
        let d   = try decoded(msg)
        #expect(d.condition == "'sport' in topics")
        #expect(d.fid       == nil)
        #expect(d.topic     == nil)
    }

    @Test("notification fields are encoded")
    func notificationFields() throws {
        let msg = FCMMessage(
            target: .fid("t"),
            notification: FCMNotification(title: "Hi", body: "There", imageURL: "https://example.com/img.png")
        )
        let d = try decoded(msg)
        #expect(d.notification?.title == "Hi")
        #expect(d.notification?.body  == "There")
        #expect(d.notification?.image == "https://example.com/img.png")
    }

    @Test("data payload is encoded")
    func dataPayload() throws {
        let msg = FCMMessage(target: .fid("t"), data: ["key": "value", "count": "3"])
        let d   = try decoded(msg)
        #expect(d.data?["key"]   == "value")
        #expect(d.data?["count"] == "3")
    }

    @Test("nil optional fields are omitted from JSON")
    func nilFieldsOmitted() throws {
        let msg    = FCMMessage(target: .fid("t"))
        let raw    = try JSONEncoder().encode(msg)
        let string = String(data: raw, encoding: .utf8)!
        #expect(!string.contains("notification"))
        #expect(!string.contains("android"))
        #expect(!string.contains("apns"))
        #expect(!string.contains("webpush"))
        #expect(!string.contains("fcm_options"))
    }

    @Test("fid encodes as the JSON key 'fid', not 'token'")
    func fidEncodesAsNewKey() throws {
        let msg    = FCMMessage(target: .fid("abc"))
        let raw    = try JSONEncoder().encode(msg)
        let string = String(data: raw, encoding: .utf8)!
        // "fid" is the current field; "token" is deprecated per the discovery doc
        #expect(string.contains("\"fid\""))
        #expect(!string.contains("\"token\""))
    }
}

// MARK: - APNS encoding

@Suite("FCMAPNSConfig encoding")
struct FCMAPNSConfigTests {

    private struct DecodedAPNS: Decodable {
        let headers: [String: String]?

        struct Payload: Decodable {
            struct APS: Decodable {
                struct Alert: Decodable {
                    let title:    String?
                    let subtitle: String?
                    let body:     String?
                }
                let alert:            Alert?
                let badge:            Int?
                let sound:            String?
                // Double? — 1.0 encodes as the JSON integer 1, as APNs requires
                let mutableContent:   Double?
                let contentAvailable: Double?
                let threadID:         String?

                private enum CodingKeys: String, CodingKey {
                    case alert, badge, sound
                    case mutableContent   = "mutable-content"
                    case contentAvailable = "content-available"
                    case threadID         = "thread-id"
                }
            }
            let aps: APS
        }
        let payload:           Payload?
        let liveActivityToken: String?

        private enum CodingKeys: String, CodingKey {
            case headers, payload
            case liveActivityToken = "live_activity_token"
        }
    }

    private func decoded(_ config: FCMAPNSConfig) throws -> DecodedAPNS {
        let data = try JSONEncoder().encode(config)
        return try JSONDecoder().decode(DecodedAPNS.self, from: data)
    }

    @Test("encodes headers")
    func headers() throws {
        let config = FCMAPNSConfig(headers: ["apns-priority": "10", "apns-push-type": "alert"])
        let d      = try decoded(config)
        #expect(d.headers?["apns-priority"]  == "10")
        #expect(d.headers?["apns-push-type"] == "alert")
    }

    @Test("encodes aps alert fields")
    func apsAlert() throws {
        let config = FCMAPNSConfig(
            payload: FCMAPNSPayload(
                aps: FCMAPS(
                    alert: FCMAPSAlert(title: "T", subtitle: "S", body: "B"),
                    badge: 7,
                    mutableContent: 1
                )
            )
        )
        let d = try decoded(config)
        #expect(d.payload?.aps.alert?.title    == "T")
        #expect(d.payload?.aps.alert?.subtitle == "S")
        #expect(d.payload?.aps.alert?.body     == "B")
        #expect(d.payload?.aps.badge           == 7)
        #expect(d.payload?.aps.mutableContent  == 1)
    }

    @Test("mutable-content uses hyphenated key and encodes as integer 1")
    func mutableContentKey() throws {
        let config = FCMAPNSConfig(
            payload: FCMAPNSPayload(aps: FCMAPS(mutableContent: 1))
        )
        let raw    = try JSONEncoder().encode(config)
        let string = String(data: raw, encoding: .utf8)!
        #expect(string.contains("mutable-content"))
        #expect(!string.contains("mutableContent"))

        let d = try decoded(config)
        #expect(d.payload?.aps.mutableContent == 1)   // Double 1.0 → JSON integer 1
    }

    @Test("live_activity_token is encoded")
    func liveActivityToken() throws {
        let config = FCMAPNSConfig(liveActivityToken: "live-token-abc")
        let d      = try decoded(config)
        #expect(d.liveActivityToken == "live-token-abc")
    }

    @Test("interruption-level and relevance-score encode with hyphenated keys")
    func interruptionLevelAndRelevance() throws {
        let config = FCMAPNSConfig(
            payload: FCMAPNSPayload(
                aps: FCMAPS(interruptionLevel: .timeSensitive, relevanceScore: 0.75)
            )
        )
        let raw = try JSONEncoder().encode(config)
        let str = String(data: raw, encoding: .utf8)!
        #expect(str.contains("interruption-level"))
        #expect(str.contains("time-sensitive"))
        #expect(str.contains("relevance-score"))
    }

    @Test("FCMAPSAlert encodes localization fields with hyphenated keys")
    func alertLocalizationKeys() throws {
        let alert = FCMAPSAlert(
            titleLocKey:  "TITLE_KEY",
            titleLocArgs: ["arg1"],
            locKey:       "BODY_KEY",
            locArgs:      ["arg2", "arg3"]
        )
        let raw = try JSONEncoder().encode(alert)
        let str = String(data: raw, encoding: .utf8)!
        #expect(str.contains("title-loc-key"))
        #expect(str.contains("loc-key"))
        #expect(str.contains("BODY_KEY"))
    }
}

// MARK: - Android encoding

@Suite("FCMAndroidConfig encoding")
struct FCMAndroidConfigTests {

    private struct DecodedAndroid: Decodable {
        let collapseKey:            String?
        let priority:               String?
        let ttl:                    String?
        let restrictedPackageName:  String?
        let directBootOk:           Bool?
        let bandwidthConstrainedOk: Bool?

        private enum CodingKeys: String, CodingKey {
            case collapseKey            = "collapse_key"
            case priority, ttl
            case restrictedPackageName  = "restricted_package_name"
            case directBootOk           = "direct_boot_ok"
            case bandwidthConstrainedOk = "bandwidth_constrained_ok"
        }
    }

    @Test("encodes all fields with snake_case keys")
    func snakeCaseKeys() throws {
        let config = FCMAndroidConfig(
            collapseKey:            "updates",
            priority:               .high,
            ttl:                    "600s",
            restrictedPackageName:  "com.example.app",
            directBootOk:           true,
            bandwidthConstrainedOk: true
        )
        let data    = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(DecodedAndroid.self, from: data)
        #expect(decoded.collapseKey            == "updates")
        #expect(decoded.priority               == "HIGH")
        #expect(decoded.ttl                    == "600s")
        #expect(decoded.restrictedPackageName  == "com.example.app")
        #expect(decoded.directBootOk           == true)
        #expect(decoded.bandwidthConstrainedOk == true)
    }

    @Test("ttl helper builds duration string")
    func ttlHelper() {
        #expect(FCMAndroidConfig.ttl(seconds: 3.5) == "3.5s")
        #expect(FCMAndroidConfig.ttl(seconds: 600)  == "600.0s")
    }

    @Test("notification priority enum encodes correctly")
    func notificationPriority() throws {
        let n    = FCMAndroidNotification(notificationPriority: .high)
        let data = try JSONEncoder().encode(n)
        let str  = String(data: data, encoding: .utf8)!
        #expect(str.contains("PRIORITY_HIGH"))
    }

    @Test("visibility enum encodes correctly")
    func visibility() throws {
        let n    = FCMAndroidNotification(visibility: .public)
        let data = try JSONEncoder().encode(n)
        let str  = String(data: data, encoding: .utf8)!
        #expect(str.contains("\"PUBLIC\""))
    }
}

// MARK: - Webpush encoding

@Suite("FCMWebpushConfig encoding")
struct FCMWebpushConfigTests {

    private struct Decoded: Decodable {
        let headers:      [String: String]?
        let data:         [String: String]?

        struct Notification: Decodable {
            let title: String?
            let body:  String?
            let icon:  String?
        }
        let notification: Notification?

        struct Options: Decodable {
            let link:           String?
            let analyticsLabel: String?

            private enum CodingKeys: String, CodingKey {
                case link
                case analyticsLabel = "analytics_label"
            }
        }
        let fcmOptions: Options?

        private enum CodingKeys: String, CodingKey {
            case headers, data, notification
            case fcmOptions = "fcm_options"
        }
    }

    @Test("encodes headers, data, notification, and fcm_options")
    func fullConfig() throws {
        let config = FCMWebpushConfig(
            headers:      ["TTL": "86400"],
            data:         ["url": "/dashboard"],
            notification: FCMWebpushNotification(title: "Web", body: "Push", icon: "https://example.com/icon.png"),
            fcmOptions:   FCMWebpushOptions(link: "https://example.com", analyticsLabel: "web-push")
        )
        let raw     = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(Decoded.self, from: raw)

        #expect(decoded.headers?["TTL"]          == "86400")
        #expect(decoded.data?["url"]             == "/dashboard")
        #expect(decoded.notification?.title      == "Web")
        #expect(decoded.notification?.icon       == "https://example.com/icon.png")
        #expect(decoded.fcmOptions?.link         == "https://example.com")
        #expect(decoded.fcmOptions?.analyticsLabel == "web-push")
    }
}

// MARK: - FCMServerErrorCode

@Suite("FCMServerErrorCode")
struct FCMServerErrorCodeTests {

    @Test("parses known error codes from raw strings")
    func parsesKnownCodes() {
        #expect(FCMServerErrorCode(rawValue: "UNREGISTERED")        == .unregistered)
        #expect(FCMServerErrorCode(rawValue: "QUOTA_EXCEEDED")      == .quotaExceeded)
        #expect(FCMServerErrorCode(rawValue: "INVALID_ARGUMENT")    == .invalidArgument)
        #expect(FCMServerErrorCode(rawValue: "UNAVAILABLE")         == .unavailable)
        #expect(FCMServerErrorCode(rawValue: "INTERNAL")            == .internal)
        #expect(FCMServerErrorCode(rawValue: "THIRD_PARTY_AUTH_ERROR") == .thirdPartyAuthError)
    }

    @Test("returns nil for unknown codes")
    func unknownCodeIsNil() {
        #expect(FCMServerErrorCode(rawValue: "FUTURE_ERROR_CODE") == nil)
    }
}

// MARK: - FCMTopicSubscription decoding

@Suite("FCMTopicSubscription")
struct FCMTopicSubscriptionTests {

    @Test("decodes a single subscription from camelCase JSON")
    func decodesSubscription() throws {
        let json = """
        {
            "name": "projects/my-project/registrations/fid123/topicSubscriptions/news",
            "topicName": "news",
            "createTime": "2026-09-26T10:00:00Z"
        }
        """
        let sub = try JSONDecoder().decode(FCMTopicSubscription.self, from: Data(json.utf8))
        #expect(sub.name       == "projects/my-project/registrations/fid123/topicSubscriptions/news")
        #expect(sub.topicName  == "news")
        #expect(sub.createTime == "2026-09-26T10:00:00Z")
    }

    @Test("decodes a page with subscriptions and nextPageToken")
    func decodesPage() throws {
        let json = """
        {
            "topicSubscriptions": [
                {
                    "name": "projects/my-project/registrations/fid123/topicSubscriptions/sport",
                    "topicName": "sport",
                    "createTime": "2026-09-01T00:00:00Z"
                },
                {
                    "name": "projects/my-project/registrations/fid123/topicSubscriptions/tech",
                    "topicName": "tech",
                    "createTime": "2026-09-02T00:00:00Z"
                }
            ],
            "nextPageToken": "token-xyz"
        }
        """
        let page = try JSONDecoder().decode(FCMTopicSubscriptionsPage.self, from: Data(json.utf8))
        #expect(page.topicSubscriptions.count == 2)
        #expect(page.topicSubscriptions[0].topicName == "sport")
        #expect(page.topicSubscriptions[1].topicName == "tech")
        #expect(page.nextPageToken == "token-xyz")
    }

    @Test("decodes an empty page without nextPageToken")
    func decodesEmptyPage() throws {
        let json = """
        {
            "topicSubscriptions": []
        }
        """
        let page = try JSONDecoder().decode(FCMTopicSubscriptionsPage.self, from: Data(json.utf8))
        #expect(page.topicSubscriptions.isEmpty)
        #expect(page.nextPageToken == nil)
    }
}

// MARK: - MockFCMClient

@Suite("MockFCMClient")
struct MockFCMClientTests {

    @Test("records sent messages")
    func recordsSentMessages() async throws {
        let mock = MockFCMClient()
        let msg  = FCMMessage(
            target: .fid("token-abc"),
            notification: FCMNotification(title: "Hello", body: "World")
        )

        _ = try await mock.send(msg)

        #expect(mock.sendCount == 1)
        #expect(mock.lastSentMessage?.notification?.title == "Hello")
    }

    @Test("throws configured send error then clears it")
    func throwsAndClearsSendError() async throws {
        let mock = MockFCMClient()
        mock.nextSendError = FCMError.serverError(
            status: 404, code: .unregistered, message: "Gone"
        )

        // First call — throws
        await #expect(throws: FCMError.self) {
            try await mock.send(FCMMessage(target: .fid("t")))
        }
        // Error is cleared automatically; second call succeeds
        _ = try await mock.send(FCMMessage(target: .fid("t")))
        #expect(mock.sendCount == 1)   // only the successful one is recorded
    }

    @Test("records batch messages")
    func recordsBatchMessages() async throws {
        let mock = MockFCMClient()
        let msgs = (1...3).map { i in FCMMessage(target: .fid("tok-\(i)")) }

        let results = try await mock.sendBatch(msgs)

        #expect(results.count  == 3)
        #expect(mock.sendCount == 3)
        #expect(results.allSatisfy { if case .success = $0 { true } else { false } })
    }

    @Test("records subscribe and unsubscribe calls")
    func recordsSubscriptionCalls() async throws {
        let mock = MockFCMClient()

        _ = try await mock.subscribe(fid: "fid-1", to: "news")
        try await mock.unsubscribe(fid: "fid-1", from: "sport")

        #expect(mock.subscribeCalls.count   == 1)
        #expect(mock.unsubscribeCalls.count == 1)
        #expect(mock.subscribeCalls[0].topic   == "news")
        #expect(mock.unsubscribeCalls[0].topic == "sport")
    }

    @Test("reset clears all state")
    func resetClearsState() async throws {
        let mock = MockFCMClient()
        _ = try await mock.send(FCMMessage(target: .fid("t")))
        mock.reset()
        #expect(mock.sendCount == 0)
    }

}

// MARK: - Live Activity

@Suite("Live Activity APS encoding")
struct FCMLiveActivityTests {

    private struct Score: Codable, Sendable { let home: Int; let away: Int }
    private struct MatchAttrs: Codable, Sendable { let matchID: String }

    // Decode the aps dict the way APNs would see it
    private struct DecodedAPS: Decodable {
        let event:          String?
        let timestamp:      Int?
        let contentState:   Score?
        let dismissalDate:  Int?
        let staleDate:      Int?
        let relevanceScore: Double?
        let attributesType: String?
        let attributes:     MatchAttrs?

        private enum CodingKeys: String, CodingKey {
            case event, timestamp
            case contentState   = "content-state"
            case dismissalDate  = "dismissal-date"
            case staleDate      = "stale-date"
            case relevanceScore = "relevance-score"
            case attributesType = "attributes-type"
            case attributes
        }
    }

    @Test("update APS encodes event, timestamp, content-state")
    func updateAPS() throws {
        let aps = FCMLiveActivityAPS(
            event:        .update,
            contentState: Score(home: 3, away: 1),
            timestamp:    1_700_000_000
        )
        let data    = try JSONEncoder().encode(aps)
        let decoded = try JSONDecoder().decode(DecodedAPS.self, from: data)
        #expect(decoded.event          == "update")
        #expect(decoded.timestamp      == 1_700_000_000)
        #expect(decoded.contentState?.home == 3)
        #expect(decoded.contentState?.away == 1)
        #expect(decoded.dismissalDate  == nil)   // .none omits the key
    }

    @Test("end APS with immediate dismissal encodes dismissal-date as 0")
    func endWithImmediateDismissal() throws {
        let aps = FCMLiveActivityAPS(
            event:        .end,
            contentState: Score(home: 3, away: 1),
            timestamp:    1_700_000_000,
            dismissalDate: .immediately
        )
        let data    = try JSONEncoder().encode(aps)
        let decoded = try JSONDecoder().decode(DecodedAPS.self, from: data)
        #expect(decoded.event         == "end")
        #expect(decoded.dismissalDate == 0)
    }

    @Test("end APS with timed dismissal encodes the timestamp")
    func endWithTimedDismissal() throws {
        let aps = FCMLiveActivityAPS(
            event:        .end,
            contentState: Score(home: 3, away: 1),
            timestamp:    1_700_000_000,
            dismissalDate: .timeIntervalSince1970InSeconds(1_700_003_600)
        )
        let data    = try JSONEncoder().encode(aps)
        let decoded = try JSONDecoder().decode(DecodedAPS.self, from: data)
        #expect(decoded.dismissalDate == 1_700_003_600)
    }

    @Test("start APS encodes event=start, attributes-type, attributes, content-state")
    func startAPS() throws {
        let aps = FCMLiveActivityStartAPS(
            contentState:   Score(home: 0, away: 0),
            timestamp:      1_700_000_000,
            attributesType: "MatchAttrs",
            attributes:     MatchAttrs(matchID: "game-1")
        )
        let data    = try JSONEncoder().encode(aps)
        let decoded = try JSONDecoder().decode(DecodedAPS.self, from: data)
        #expect(decoded.event          == "start")
        #expect(decoded.attributesType == "MatchAttrs")
        #expect(decoded.attributes?.matchID == "game-1")
        #expect(decoded.contentState?.home  == 0)
    }

    @Test("FCMLiveActivityDismissalDate.none omits dismissal-date key")
    func dismissalNoneOmitsKey() throws {
        let aps    = FCMLiveActivityAPS(event: .end, contentState: Score(home: 0, away: 0),
                                        timestamp: 0, dismissalDate: .none)
        let raw    = try JSONEncoder().encode(aps)
        let string = String(data: raw, encoding: .utf8)!
        #expect(!string.contains("dismissal-date"))
    }
}
