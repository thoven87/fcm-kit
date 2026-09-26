[![Build](https://github.com/thoven87/fcm-kit/workflows/test/badge.svg)](https://github.com/thoven87/fcm-kit/actions)
[![Documentation](https://img.shields.io/badge/documentation-blueviolet.svg)](https://swiftpackageindex.com/thoven87/fcm-kit/documentation)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fthoven87%2Ffcm-kit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/thoven87/fcm-kit)<br>
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fthoven87%2Ffcm-kit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/thoven87/fcm-kit)

<h1>FCMKit</h1>

A non-blocking, Swift 6-native client for sending push notifications through [Firebase Cloud Messaging (FCM) HTTP v1](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages/send), built on [AsyncHTTPClient](https://github.com/swift-server/async-http-client) and [JWTKit](https://github.com/vapor/jwt-kit).

- [Installation](#installation)
- [Getting Started](#getting-started)
- [Sending to a device token](#sending-to-a-device-token)
- [Sending to a topic](#sending-to-a-topic)
- [Sending to a condition](#sending-to-a-condition)
- [Platform-specific payloads](#platform-specific-payloads)
- [Batch sending](#batch-sending)
- [Dry-run validation](#dry-run-validation)
- [Credentials](#credentials)
- [Example](#example)

## Installation

Add the package as a dependency in your [**Package.swift**](https://github.com/swiftlang/swift-package-manager#getting-started):

```swift
dependencies: [
    .package(url: "https://github.com/thoven87/fcm-kit.git", from: "1.0.0"),
]
```

Then add `FCMKit` to your target:

```swift
.target(name: "MyTarget", dependencies: [
    .product(name: "FCMKit", package: "fcm-kit"),
])
```

## Getting Started

FCMKit uses a Firebase **service-account** JSON file for authentication. Download it from the Firebase console under **Project Settings → Service Accounts → Generate new private key**.

Create an `HTTPClient` (manage its lifecycle yourself) and an `FCMClient`:

```swift
import AsyncHTTPClient
import FCMKit

let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
defer { try? await httpClient.shutdown() }

let account = try ServiceAccount.load(contentsOfFile: "/run/secrets/sa.json")

let client = try FCMClient(
    credentials: account,
    httpClient:  httpClient,
    decoder:     JSONDecoder(),
    encoder:     JSONEncoder()
)
```

## Sending to a device token

```swift
let messageID = try await client.send(
    FCMMessage(
        target: .token("device-registration-token"),
        notification: FCMNotification(title: "Hello", body: "World")
    )
)
print("Sent:", messageID)
```

## Sending to a topic

```swift
try await client.send(
    FCMMessage(
        target: .topic("breaking-news"),
        notification: FCMNotification(title: "Breaking", body: "Swift 6 ships!")
    )
)
```

## Sending to a condition

```swift
try await client.send(
    FCMMessage(
        target: .condition("'sport' in topics || 'tech' in topics"),
        notification: FCMNotification(title: "Update", body: "Check it out")
    )
)
```

## Platform-specific payloads

### APNS (Apple Push Notification service)

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
        ttl: FCMAndroidConfig.ttl(seconds: 3_600),
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

## Batch sending

`sendBatch` fetches the OAuth token once, then fires all HTTP requests concurrently via a `ThrowingTaskGroup`. Results are returned in the same order as the input, with per-message `Result` values so one failure doesn't cancel the rest.

```swift
let messages: [FCMMessage] = deviceTokens.map { token in
    FCMMessage(
        target: .token(token),
        notification: FCMNotification(title: "Hi", body: "Everyone")
    )
}

let results = try await client.sendBatch(messages)

for (index, result) in results.enumerated() {
    switch result {
    case .success(let id):  print("[\(index)] sent:", id)
    case .failure(let err): print("[\(index)] failed:", err)
    }
}
```

## Dry-run validation

Pass `validateOnly: true` to have FCM validate the message structure without delivering it — useful in CI or staging environments:

```swift
try await client.send(message, validateOnly: true)
```

## Credentials

FCMKit provides three ways to load a `ServiceAccount`, so you can pick whatever fits your deployment:

```swift
// From a file path
let account = try ServiceAccount.load(contentsOfFile: "/run/secrets/sa.json")

// From a raw JSON string (environment variable, secret manager, etc.)
let json    = ProcessInfo.processInfo.environment["FIREBASE_SA_JSON"]!
let account = try ServiceAccount.load(fromJSON: json)

// From Data
let account = try ServiceAccount.load(from: jsonData)
```

## Example

A runnable server example lives in [`Sources/FCMKitExample/Program.swift`](Sources/FCMKitExample/Program.swift).

```sh
# Using an inline JSON string
FIREBASE_SA_JSON='{ ... }' DEVICE_TOKEN='abc123' swift run FCMKitExample

# Or pointing at a file
SA_PATH=/run/secrets/sa.json DEVICE_TOKEN='abc123' swift run FCMKitExample
```
