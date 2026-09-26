// FCMKitExample — a runnable demonstration of FCMKit.
//
// Configure via environment variables, then run:
//
//   FIREBASE_SA_JSON='{ ... }' DEVICE_TOKEN='abc123' swift run FCMKitExample
//
// Or point at a file:
//
//   SA_PATH=/run/secrets/sa.json DEVICE_TOKEN='abc123' swift run FCMKitExample

import Foundation
import AsyncHTTPClient
import FCMKit

@main
struct Program {
    static func main() async {
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        do {
            try await run(httpClient: httpClient)
        } catch {
            fputs("Error: \(error)\n", stderr)
        }
        // Shutdown is always attempted, even on error.
        try? await httpClient.shutdown()
    }

    // MARK: -

    static func run(httpClient: HTTPClient) async throws {

        // ── Credentials ────────────────────────────────────────────────────────

        let credentials: ServiceAccount

        if let json = ProcessInfo.processInfo.environment["FIREBASE_SA_JSON"] {
            // Inline JSON string — handy for secret managers or CI env vars.
            credentials = try ServiceAccount.load(fromJSON: json)
        } else if let path = ProcessInfo.processInfo.environment["SA_PATH"] {
            // File path on disk.
            credentials = try ServiceAccount.load(contentsOfFile: path)
        } else {
            fputs(
                """
                Set one of:
                  FIREBASE_SA_JSON  — raw service-account JSON string
                  SA_PATH           — path to service-account JSON file\n
                """,
                stderr
            )
            exit(1)
        }

        let deviceToken = ProcessInfo.processInfo.environment["DEVICE_TOKEN"] ?? ""

        // ── Client ─────────────────────────────────────────────────────────────

        let client = try FCMClient(
            credentials:   credentials,
            httpClient:    httpClient,
            decoder:       JSONDecoder(),
            encoder:       JSONEncoder(),
            configuration: FCMConfiguration(requestTimeout: 15)
        )

        // ── Single send ────────────────────────────────────────────────────────

        print("Sending to device token…")

        let messageID = try await client.send(
            FCMMessage(
                target: .token(deviceToken),
                notification: FCMNotification(
                    title: "Hello from FCMKit!",
                    body:  "A clean, Swift 6-native FCM client."
                ),
                data: ["deeplink": "/home"],
                android: FCMAndroidConfig(
                    priority: .high,
                    ttl: FCMAndroidConfig.ttl(seconds: 3_600),
                    notification: FCMAndroidNotification(
                        title: "Hello from FCMKit!",
                        body:  "A clean, Swift 6-native FCM client.",
                        color: "#4285F4"
                    )
                ),
                apns: FCMAPNSConfig(
                    headers: ["apns-priority": "10"],
                    payload: FCMAPNSPayload(
                        aps: FCMAPS(
                            alert: FCMAPSAlert(
                                title: "Hello from FCMKit!",
                                body:  "A clean, Swift 6-native FCM client."
                            ),
                            badge: 1,
                            sound: "default",
                            mutableContent: 1
                        )
                    )
                )
            )
        )

        print("✓ Sent — message ID: \(messageID)")

        // ── Batch send ─────────────────────────────────────────────────────────

        print("\nSending batch of 3 messages to a topic…")

        let batch: [FCMMessage] = (1...3).map { i in
            FCMMessage(
                target: .topic("demo"),
                notification: FCMNotification(title: "Batch \(i)/3", body: "Hello!")
            )
        }

        let results = try await client.sendBatch(batch)

        for (i, result) in results.enumerated() {
            switch result {
            case .success(let id):  print("  [\(i)] ✓ \(id)")
            case .failure(let err): print("  [\(i)] ✗ \(err)")
            }
        }
    }
}
