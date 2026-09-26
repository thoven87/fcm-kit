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

let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
// Manage the HTTPClient lifecycle in your own shutdown/teardown path.

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

### Notification Payload
- ``FCMNotification``

### Platform Configs
- ``FCMAPNSConfig``
- ``FCMAndroidConfig``
- ``FCMWebpushConfig``

### Coding
- ``FCMJSONDecoder``
- ``FCMJSONEncoder``
