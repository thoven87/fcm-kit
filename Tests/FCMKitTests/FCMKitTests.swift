import Testing
import Foundation
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
}

// MARK: - FCMMessage encoding

@Suite("FCMMessage encoding")
struct FCMMessageEncodingTests {

    // Helpers
    private struct DecodedMessage: Decodable {
        let token:     String?
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

    @Test("token target sets only token field")
    func tokenTarget() throws {
        let msg = FCMMessage(target: .token("tok-xyz"))
        let d   = try decoded(msg)
        #expect(d.token     == "tok-xyz")
        #expect(d.topic     == nil)
        #expect(d.condition == nil)
    }

    @Test("topic target sets only topic field")
    func topicTarget() throws {
        let msg = FCMMessage(target: .topic("breaking-news"))
        let d   = try decoded(msg)
        #expect(d.topic     == "breaking-news")
        #expect(d.token     == nil)
        #expect(d.condition == nil)
    }

    @Test("condition target sets only condition field")
    func conditionTarget() throws {
        let msg = FCMMessage(target: .condition("'sport' in topics"))
        let d   = try decoded(msg)
        #expect(d.condition == "'sport' in topics")
        #expect(d.token     == nil)
        #expect(d.topic     == nil)
    }

    @Test("notification fields are encoded")
    func notificationFields() throws {
        let msg = FCMMessage(
            target: .token("t"),
            notification: FCMNotification(title: "Hi", body: "There", imageURL: "https://example.com/img.png")
        )
        let d = try decoded(msg)
        #expect(d.notification?.title == "Hi")
        #expect(d.notification?.body  == "There")
        #expect(d.notification?.image == "https://example.com/img.png")
    }

    @Test("data payload is encoded")
    func dataPayload() throws {
        let msg = FCMMessage(target: .token("t"), data: ["key": "value", "count": "3"])
        let d   = try decoded(msg)
        #expect(d.data?["key"]   == "value")
        #expect(d.data?["count"] == "3")
    }

    @Test("nil optional fields are omitted from JSON")
    func nilFieldsOmitted() throws {
        let msg    = FCMMessage(target: .token("t"))
        let raw    = try JSONEncoder().encode(msg)
        let string = String(data: raw, encoding: .utf8)!
        #expect(!string.contains("notification"))
        #expect(!string.contains("android"))
        #expect(!string.contains("apns"))
        #expect(!string.contains("webpush"))
    }
}

// MARK: - APNS encoding

@Suite("FCMAPNSConfig encoding")
struct FCMAPNSConfigTests {

    private struct DecodedAPNS: Decodable {
        struct Headers: Decodable {}
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
        let payload: Payload?
    }

    private func decoded(_ config: FCMAPNSConfig) throws -> DecodedAPNS {
        let data = try JSONEncoder().encode(config)
        return try JSONDecoder().decode(DecodedAPNS.self, from: data)
    }

    @Test("encodes headers")
    func headers() throws {
        let config = FCMAPNSConfig(headers: ["apns-priority": "10", "apns-push-type": "alert"])
        let d      = try decoded(config)
        #expect(d.headers?["apns-priority"]   == "10")
        #expect(d.headers?["apns-push-type"]  == "alert")
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

    @Test("mutable-content uses hyphenated key")
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
}

// MARK: - Android encoding

@Suite("FCMAndroidConfig encoding")
struct FCMAndroidConfigTests {

    private struct DecodedAndroid: Decodable {
        let collapseKey:           String?
        let priority:              String?
        let ttl:                   String?
        let restrictedPackageName: String?

        private enum CodingKeys: String, CodingKey {
            case collapseKey           = "collapse_key"
            case priority, ttl
            case restrictedPackageName = "restricted_package_name"
        }
    }

    @Test("encodes all fields with snake_case keys")
    func snakeCaseKeys() throws {
        let config = FCMAndroidConfig(
            collapseKey:           "updates",
            priority:              .high,
            ttl:                   "600s",
            restrictedPackageName: "com.example.app"
        )
        let data    = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(DecodedAndroid.self, from: data)
        #expect(decoded.collapseKey           == "updates")
        #expect(decoded.priority              == "HIGH")
        #expect(decoded.ttl                   == "600s")
        #expect(decoded.restrictedPackageName == "com.example.app")
    }

    @Test("ttl helper builds duration string")
    func ttlHelper() {
        #expect(FCMAndroidConfig.ttl(seconds: 3.5) == "3.5s")
        #expect(FCMAndroidConfig.ttl(seconds: 600)  == "600.0s")
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
    }

    @Test("encodes headers, data, and notification")
    func fullConfig() throws {
        let config = FCMWebpushConfig(
            headers:      ["TTL": "86400"],
            data:         ["url": "/dashboard"],
            notification: FCMWebpushNotification(title: "Web", body: "Push", icon: "https://example.com/icon.png")
        )
        let raw     = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(Decoded.self, from: raw)

        #expect(decoded.headers?["TTL"]          == "86400")
        #expect(decoded.data?["url"]             == "/dashboard")
        #expect(decoded.notification?.title      == "Web")
        #expect(decoded.notification?.icon       == "https://example.com/icon.png")
    }
}
