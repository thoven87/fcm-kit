# ``FCMKit``

A clean, high-performance Firebase Cloud Messaging (FCM) client for Swift 6, built on AsyncHTTPClient and JWTKit.

## Overview

FCMKit handles the full FCM HTTP v1 send flow:

1. Load a Firebase service-account credential (JSON file, raw string, or `Data`).
2. Automatically sign a short-lived JWT and exchange it for an OAuth 2.0 Bearer token.
3. Cache that token (auto-refreshed 60 s before expiry) across every send call.
4. Encode your ``FCMMessage`` into a `ByteBuffer` and POST it to the FCM endpoint.
5. Decode the structured response — or surface a typed ``FCMError``.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/thoven87/fcm-kit.git", from: "1.0.0"),
],
targets: [
    .target(name: "MyTarget", dependencies: [
        .product(name: "FCMKit", package: "fcm-kit"),
    ]),
]
```

## Getting Started

> Before writing any Swift code, complete the Firebase project and credentials setup described in <doc:GoogleCloudSetup>.

### 1. Load credentials

Download your service-account JSON from the Firebase console
(**Project Settings → Service Accounts → Generate new private key**).

```swift
// From a file path
let account = try ServiceAccount.load(contentsOfFile: "/run/secrets/sa.json")

// From a raw JSON string (e.g. an environment variable or secret manager)
let json    = ProcessInfo.processInfo.environment["FIREBASE_SA_JSON"]!
let account = try ServiceAccount.load(fromJSON: json)

// From Data
let account = try ServiceAccount.load(from: jsonData)
```

### 2. Create the client

`FCMClient` is generic over ``FCMJSONDecoder`` and ``FCMJSONEncoder``, so you can
plug in any Foundation-compatible coder. `JSONDecoder`/`JSONEncoder` work out of the box.

```swift
import AsyncHTTPClient

let httpClient = HTTPClient.shared  // process-wide singleton; no shutdown needed

let client = try FCMClient(
    credentials: account,
    httpClient:  httpClient,
    decoder:     JSONDecoder(),
    encoder:     JSONEncoder()
)
```

## Sending Notifications

### To a device token

```swift
let messageID = try await client.send(
    FCMMessage(
        target: .token("device-registration-token"),
        notification: FCMNotification(title: "Hello", body: "World")
    )
)
```

### To a topic

```swift
try await client.send(
    FCMMessage(target: .topic("breaking-news"),
               notification: FCMNotification(title: "Breaking", body: "…"))
)
```

### With a boolean condition

```swift
try await client.send(
    FCMMessage(target: .condition("'sport' in topics || 'tech' in topics"),
               notification: FCMNotification(title: "Update", body: "…"))
)
```

## Platform-Specific Payloads

### APNS (Apple)

```swift
FCMMessage(
    target: .token(token),
    apns: FCMAPNSConfig(
        headers: ["apns-priority": "10"],
        payload: FCMAPNSPayload(
            aps: FCMAPS(
                alert: FCMAPSAlert(title: "Hi", subtitle: "Sub", body: "Body"),
                badge: 1,
                sound: "default",
                mutableContent: 1
            )
        )
    )
)
```

### Android

```swift
FCMMessage(
    target: .token(token),
    android: FCMAndroidConfig(
        priority: .high,
        ttl: FCMAndroidConfig.ttl(seconds: 3600),
        notification: FCMAndroidNotification(
            title: "Hi",
            body:  "Android body",
            icon:  "ic_notification",
            color: "#FF5722"
        )
    )
)
```

### Web Push

```swift
FCMMessage(
    target: .topic("web-users"),
    webpush: FCMWebpushConfig(
        headers: ["TTL": "86400"],
        notification: FCMWebpushNotification(title: "Hi", body: "Web body")
    )
)
```

## Live Activities (iOS 16+)

FCM forwards Live Activity pushes to APNs via the `live_activity_token` field.
FCMKit provides typed, generic methods that handle the `aps` payload construction for you.

### Prerequisites

- App has the **ActivityKit push notifications** entitlement
- Your `ActivityAttributes` conformer is `Encodable & Sendable`
- Push-to-start requires iOS 17.2+; update/end requires iOS 16.2+

### Update a running Live Activity

```swift
struct GameScore: Encodable, Sendable { let home: Int; let away: Int }

try await client.sendLiveActivity(
    target:            .fid(deviceToken),
    liveActivityToken: activity.pushToken,          // from ActivityKit
    event:             .update,
    contentState:      GameScore(home: 3, away: 1),
    timestamp:         Int(Date().timeIntervalSince1970)
)
```

### End a Live Activity

```swift
try await client.sendLiveActivity(
    target:            .fid(deviceToken),
    liveActivityToken: activity.pushToken,
    event:             .end,
    contentState:      GameScore(home: 3, away: 1),
    timestamp:         Int(Date().timeIntervalSince1970),
    dismissalDate:     .immediately             // or .timeIntervalSince1970InSeconds(...)
)
```

### Start a Live Activity remotely (push-to-start, iOS 17.2+)

```swift
struct GameAttributes: Encodable, Sendable { let matchID: String }

try await client.sendLiveActivity(
    target:            .fid(deviceToken),
    liveActivityToken: activity.pushToStartToken,   // from ActivityKit
    contentState:      GameScore(home: 0, away: 0),
    attributesType:    "GameAttributes",            // exact Swift type name
    attributes:        GameAttributes(matchID: "final-2026"),
    timestamp:         Int(Date().timeIntervalSince1970),
    alert:             FCMAPSAlert(title: "Match started!", body: "Tap to follow live.")
)
```

## Topic Subscriptions

FCMKit implements the FCM v1 Topic Subscription API — the modern replacement for the
deprecated IID `batchAdd`/`batchRemove` endpoints.

### Subscribe

```swift
// Idempotent — returns existing subscription without error if already subscribed
let sub = try await client.subscribe(fid: deviceToken, to: "breaking-news")
print(sub.createTime ?? "")
```

### Unsubscribe

```swift
// Idempotent — no error if not subscribed
try await client.unsubscribe(fid: deviceToken, from: "breaking-news")
```

### Get a specific subscription

```swift
let sub = try await client.getSubscription(fid: deviceToken, topic: "breaking-news")
```

### List all subscriptions for a device

```swift
var pageToken: String? = nil
repeat {
    let page = try await client.listSubscriptions(fid: deviceToken, pageToken: pageToken)
    page.topicSubscriptions.forEach { print($0.topicName ?? "") }
    pageToken = page.nextPageToken
} while pageToken != nil
```

## Batch Sending

``FCMClient/sendBatch(_:)`` fetches the OAuth token once and then fires all
HTTP requests concurrently via a `ThrowingTaskGroup`. Results are returned in
the same order as the input, with per-message `Result` values.

```swift
let messages: [FCMMessage] = deviceTokens.map { token in
    FCMMessage(target: .token(token),
               notification: FCMNotification(title: "Hi", body: "Everyone"))
}

let results = try await client.sendBatch(messages)

for (index, result) in results.enumerated() {
    switch result {
    case .success(let id):  print("[\(index)] sent: \(id)")
    case .failure(let err): print("[\(index)] failed: \(err)")
    }
}
```

## Validation (Dry-Run)

Pass `validateOnly: true` to have FCM validate the message structure without
delivering it — useful in CI or staging:

```swift
try await client.send(message, validateOnly: true)
```

## Topics

### Essentials
- ``FCMClient``
- ``ServiceAccount``
- ``FCMConfiguration``
- ``FCMMessage``
- ``FCMError``
- ``FCMServerErrorCode``

### Live Activities
- ``FCMLiveActivityEvent``
- ``FCMLiveActivityDismissalDate``
- ``FCMLiveActivityAPS``
- ``FCMLiveActivityStartAPS``

### Topic Subscriptions
- ``FCMTopicSubscription``
- ``FCMTopicSubscriptionsPage``

### Notification Payload
- ``FCMNotification``

### Platform Configs
- ``FCMAPNSConfig``
- ``FCMAndroidConfig``
- ``FCMWebpushConfig``

### Coding
- ``FCMJSONDecoder``
- ``FCMJSONEncoder``

### Guides
- <doc:GoogleCloudSetup>
- <doc:TestingWithFCMKit>
