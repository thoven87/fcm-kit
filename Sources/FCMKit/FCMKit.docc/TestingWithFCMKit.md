# Testing with FCMKit

Write fast, isolated unit tests for code that sends push notifications using ``FCMClientProtocol`` and ``MockFCMClient``.

## Overview

`FCMClient` talks to Google's servers, which makes it unsuitable for unit tests. FCMKit
solves this with two building blocks:

- **``FCMClientProtocol``** — a protocol that exposes every public non-generic method.
  Depend on `any FCMClientProtocol` in your application types instead of the concrete class.
- **``MockFCMClient``** — an `actor` test double (from `FCMKitTestSupport`) that records
  every call and returns configurable stub values without touching the network.

---

## Step 1 — Depend on the Protocol in Your Application Code

```swift
// NotificationService.swift

import FCMKit

struct NotificationService: Sendable {
    private let fcm: any FCMClientProtocol   // ← protocol, not FCMClient

    init(fcm: any FCMClientProtocol) {
        self.fcm = fcm
    }

    func sendAlert(to token: String, title: String, body: String) async throws {
        try await fcm.send(
            FCMMessage(
                target: .fid(token),
                notification: FCMNotification(title: title, body: body)
            )
        )
    }

    func subscribe(token: String, to topic: String) async throws {
        try await fcm.subscribe(fid: token, to: topic)
    }
}
```

In production, inject a real ``FCMClient``:

```swift
let client = try FCMClient(
    credentials: account,
    httpClient:  .shared,
    decoder:     JSONDecoder(),
    encoder:     JSONEncoder()
)
let service = NotificationService(fcm: client)
```

---

## Step 2 — Add FCMKitTestSupport to Your Test Target

```swift
// Package.swift
.testTarget(
    name: "MyAppTests",
    dependencies: [
        "MyApp",
        .product(name: "FCMKitTestSupport", package: "fcm-kit"),
    ]
)
```

---

## Step 3 — Write Tests with MockFCMClient

```swift
import Testing
import FCMKit
import FCMKitTestSupport

@Suite("NotificationService")
struct NotificationServiceTests {

    // MARK: - Happy path

    @Test("sends the correct FID and notification content")
    func sendsCorrectMessage() async throws {
        let mock    = MockFCMClient()
        let service = NotificationService(fcm: mock)

        try await service.sendAlert(to: "device-abc", title: "Hello", body: "World")

        // Assert call count
        let count = await mock.sendCount
        #expect(count == 1)

        // Inspect the recorded message
        let msg = try #require(await mock.lastSentMessage)
        guard case .fid(let fid) = msg.target else {
            Issue.record("Expected .fid target"); return
        }
        #expect(fid                    == "device-abc")
        #expect(msg.notification?.title == "Hello")
        #expect(msg.notification?.body  == "World")
    }

    // MARK: - Batch

    @Test("batch send records all messages")
    func batchSendRecordsAll() async throws {
        let mock    = MockFCMClient()
        let tokens  = ["tok-1", "tok-2", "tok-3"]

        // Call sendBatch directly through the protocol
        let results = try await mock.sendBatch(
            tokens.map { FCMMessage(target: .fid($0)) }
        )

        #expect(results.count == 3)
        let count = await mock.sendCount
        #expect(count == 3)
    }

    // MARK: - Error handling

    @Test("propagates FCM server errors")
    func propagatesError() async throws {
        let mock    = MockFCMClient()
        let service = NotificationService(fcm: mock)

        // Arrange — direct assignment, no await needed
        mock.nextSendError = FCMError.serverError(
            status:  404,
            code:    .unregistered,
            message: "Token not registered"
        )

        // Act + Assert
        await #expect(throws: FCMError.self) {
            try await service.sendAlert(to: "stale-token", title: "Hi", body: "")
        }

        // Message should NOT be recorded when an error is thrown
        let count = await mock.sendCount
        #expect(count == 0)
    }

    // MARK: - Topic subscriptions

    @Test("subscribes device to topic")
    func subscribesToTopic() async throws {
        let mock    = MockFCMClient()
        let service = NotificationService(fcm: mock)

        try await service.subscribe(token: "device-abc", to: "breaking-news")

        let calls = await mock.subscribeCalls
        #expect(calls.count == 1)
        #expect(calls[0].fid   == "device-abc")
        #expect(calls[0].topic == "breaking-news")
    }
}
```

> Note: `MockFCMClient` is a `final class`, so properties are directly readable and writable — no `await` needed.

---

## Setting Error Stubs

`MockFCMClient` is a plain `final class`, so stubs are directly assignable — no `await` needed:

```swift
// Throw on the next send() call (cleared automatically after throwing once)
mock.nextSendError = FCMError.serverError(
    status: 429, code: .quotaExceeded, message: "Rate limit exceeded"
)

// Throw on the next topic subscription call
mock.nextSubscriptionError = FCMError.serverError(
    status: 403, code: .senderIDMismatch, message: "Wrong project"
)

// Customise the returned message ID
mock.stubbedMessageID = "projects/my-project/messages/12345"
```

---

## Testing Live Activity Sends

Both `sendLiveActivity` overloads are generic methods and cannot be
expressed in a protocol requirement. Two practical approaches:

### 1. Test the APS payload in isolation

The simplest approach: encode the APS struct and assert on the JSON directly —
no network, no mock needed.

```swift
@Test("encodes the correct event and content-state")
func liveActivityAPSEncoding() throws {
    struct Score: Encodable, Sendable { let home: Int; let away: Int }

    let aps = FCMLiveActivityAPS(
        event:        .update,
        contentState: Score(home: 3, away: 1),
        timestamp:    1_700_000_000
    )

    let data    = try JSONEncoder().encode(aps)
    let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: data)
    // assert fields...
}
```

### 2. Use validateOnly: true against real Firebase

Send real pushes in a CI staging environment with `validateOnly: true` — FCM validates
the message structure and returns a response without delivering to any device.

```swift
let id = try await realClient.sendLiveActivity(
    target:            .fid("test-token"),
    liveActivityToken: "push-token",
    event:             .update,
    contentState:      Score(home: 0, away: 0),
    timestamp:         Int(Date().timeIntervalSince1970),
    validateOnly:      true   // ← no actual delivery
)
```

> Important: `validateOnly` is on ``FCMClient/send(_:validateOnly:)`` (regular messages).
> Live Activity sends do not yet expose a `validateOnly` parameter; test them
> via the payload encoding approach above.

---

## Resetting State Between Tests

Call `reset()` to clear all recorded calls and pending errors:

```swift
@Suite("NotificationService")
struct NotificationServiceTests {
    let mock    = MockFCMClient()
    var service: NotificationService { NotificationService(fcm: mock) }

    init() {
        mock.reset()
    }
}
```

---

## See Also

- ``FCMClientProtocol``
- ``FCMMessage``
- ``FCMError``
- ``FCMServerErrorCode``
