# Setting Up Google Cloud & Firebase

Configure a Firebase project, generate service-account credentials, and connect FCMKit to Google's APIs.

## Overview

FCMKit authenticates with Google using a **service account** — a machine identity tied to your Firebase project. The service account's private key is used to sign short-lived JWTs, which are exchanged for OAuth 2.0 Bearer tokens that authorise each FCM send request.

Before writing any Swift code you need to:

1. Create (or use) a Firebase project
2. Enable the Firebase Cloud Messaging API
3. Create a service account and download its JSON key
4. (iOS only) Upload your APNs key so Firebase can relay pushes to Apple
5. Load the JSON key in your server code

---

## Step 1 — Create a Firebase Project

1. Open the [Firebase console](https://console.firebase.google.com).
2. Click **Add project** and follow the wizard.
3. You do **not** need to enable Google Analytics for FCM to work.

If you already have a Google Cloud project, you can import it into Firebase at the same URL.

---

## Step 2 — Enable the FCM API

The Firebase console enables FCM automatically when you register an app, but it is worth confirming:

1. Go to the [Google Cloud Console API Library](https://console.cloud.google.com/apis/library).
2. Search for **Firebase Cloud Messaging API**.
3. Select your project from the project picker at the top.
4. Click **Enable** if it is not already enabled.

> Note: You may also see a legacy **Cloud Messaging API (Legacy)** entry. FCMKit uses only the HTTP v1 API — you do not need the legacy API.

---

## Step 3 — Create a Service Account and Download the Key

The service account is what FCMKit uses to prove its identity to Google.

1. In the Firebase console, open **Project Settings** (the gear icon).
2. Select the **Service accounts** tab.
3. Click **Generate new private key** → **Generate key**.
4. A JSON file downloads automatically. **Store it securely** — it contains a private key that grants access to your project.

The downloaded JSON looks like this (values abbreviated):

```json
{
  "type": "service_account",
  "project_id": "my-project-abc123",
  "private_key_id": "a1b2c3d4e5f6...",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQ...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xyz@my-project-abc123.iam.gserviceaccount.com",
  "token_uri": "https://oauth2.googleapis.com/token"
}
```

FCMKit reads this file with ``ServiceAccount/load(contentsOfFile:)``, ``ServiceAccount/load(from:)``, or ``ServiceAccount/load(fromJSON:)``.

### Securing the key in production

- **Never commit** the JSON to source control.
- In containerised environments (Docker, Kubernetes), mount the file as a secret volume
  or inject the JSON string via an environment variable.
- On AWS/GCP/Azure, use the platform's secret manager (Secrets Manager, Secret Manager, Key Vault)
  and load the value at startup.

```swift
// From a file path (local / mounted secret volume)
let account = try ServiceAccount.load(contentsOfFile: "/run/secrets/firebase-sa.json")

// From an environment variable (CI, secret manager output)
let json    = ProcessInfo.processInfo.environment["FIREBASE_SA_JSON"]!
let account = try ServiceAccount.load(fromJSON: json)
```

---

## Step 4 — Verify the Service Account Role (Optional)

FCMKit only needs the **Firebase Cloud Messaging API User** role. If you need to reduce blast radius, verify in the [IAM console](https://console.cloud.google.com/iam-admin/iam):

1. Select your project.
2. Find the `firebase-adminsdk-…@…iam.gserviceaccount.com` principal.
3. Confirm it has at least the **Firebase Cloud Messaging API User** role
   (`roles/cloudmessaging.messages.create`).

The default service account created by Firebase has the **Editor** role, which is broader than necessary for FCM sends only.

---

## Step 5 — iOS: Upload Your APNs Key to Firebase

FCM acts as a relay between your server and APNs. To do this, Firebase needs your APNs **Auth Key** (`.p8` file from the Apple Developer portal).

1. In the Firebase console, open **Project Settings → Cloud Messaging**.
2. Under **Apple app configuration**, click **Upload** next to **APNs Authentication Key**.
3. Upload the `.p8` file, and enter the **Key ID** and **Team ID** from your Apple Developer account.

> Important: If you use APNs **certificates** instead of auth keys, the auth key approach is strongly preferred — it covers all apps under your team ID and does not expire.

Once uploaded, Firebase transparently relays any message that contains an ``FCMAPNSConfig`` to APNs on your behalf.

---

## Step 6 — Initialise FCMKit

With the service account JSON in hand, create an ``FCMClient``:

```swift
import AsyncHTTPClient
import FCMKit

// HTTPClient.shared is a process-wide singleton managed by AsyncHTTPClient.
// You do not need to create or shut it down yourself.
let httpClient = HTTPClient.shared

let credentials = try ServiceAccount.load(contentsOfFile: "/run/secrets/firebase-sa.json")

let client = try FCMClient(
    credentials: credentials,
    httpClient:  httpClient,
    decoder:     JSONDecoder(),
    encoder:     JSONEncoder()
)
```

`FCMClient` handles token acquisition and caching automatically. The first `send` call
fetches an OAuth 2.0 Bearer token from Google (valid for 1 hour) and reuses it for
subsequent calls, refreshing 60 seconds before expiry.

---

## Common Errors During Setup

| Error | Likely cause |
|---|---|
| ``FCMError/invalidCredentials(_:)`` at init | The JSON file is malformed, truncated, or missing the `private_key` field |
| ``FCMError/tokenGenerationFailed(_:)`` on first send | The service account does not have the FCM role, or the FCM API is not enabled in the project |
| ``FCMError/serverError(status:code:message:)`` with ``FCMServerErrorCode/thirdPartyAuthError`` | APNs key not uploaded to Firebase, or the key has been revoked |
| ``FCMError/serverError(status:code:message:)`` with ``FCMServerErrorCode/unregistered`` | The device token is stale — remove it from your database |
| ``FCMError/serverError(status:code:message:)`` with ``FCMServerErrorCode/senderIDMismatch`` | The Firebase project used to send does not match the project the app registered with |

---

---

## Cloud Run — Application Default Credentials (No Key File)

When running on Google Cloud Platform, the compute instance already has an
identity through its attached **service account**. FCMKit can fetch OAuth tokens
directly from the local GCP metadata server — no JSON file to manage, rotate, or
secure.

### 1. Grant the Cloud Run service account the FCM role

1. In the [Google Cloud Console IAM page](https://console.cloud.google.com/iam-admin/iam),
   find the service account used by your Cloud Run service
   (typically `{project-number}-compute@developer.gserviceaccount.com` or a custom one).
2. Grant it the **Firebase Cloud Messaging API User** role
   (`roles/cloudmessaging.messages.create`).

### 2. Set the project ID as an environment variable in Cloud Run

In the Cloud Run service configuration (Console or `gcloud`):

```
FCM_PROJECT_ID=my-firebase-project
```

This is the only environment variable your service needs for FCM.

### 3. Initialise FCMClient without credentials

```swift
import FCMKit

let client = FCMClient(
    projectID:  ProcessInfo.processInfo.environment["FCM_PROJECT_ID"]!,
    httpClient: .shared,
    decoder:    JSONDecoder(),
    encoder:    JSONEncoder()
)
```

That's it. FCMKit calls `http://metadata.google.internal/…/token` with the
`Metadata-Flavor: Google` header and caches the resulting token with the same
60-second early-refresh logic used for service accounts.

### Handling both environments

A common pattern in server code that runs both locally (service account JSON)
and on GCP (ADC):

```swift
let client: FCMClient<JSONDecoder, JSONEncoder>

if let projectID = ProcessInfo.processInfo.environment["FCM_PROJECT_ID"] {
    // GCP deployment — use Application Default Credentials
    client = FCMClient(
        projectID:  projectID,
        httpClient: .shared,
        decoder:    JSONDecoder(),
        encoder:    JSONEncoder()
    )
} else {
    // Local development — use service account JSON
    let json    = ProcessInfo.processInfo.environment["FIREBASE_SA_JSON"]!
    let account = try ServiceAccount.load(fromJSON: json)
    client = try FCMClient(
        credentials: account,
        httpClient:  .shared,
        decoder:     JSONDecoder(),
        encoder:     JSONEncoder()
    )
}
```

> Note: The GCP metadata server (`http://metadata.google.internal`) is only reachable
> from within GCP infrastructure. Calling the ADC init locally will cause token
> refresh to fail at the first send.

---

## See Also

- ``ServiceAccount``
- ``FCMClient``
- ``FCMConfiguration``
- ``FCMError``
- [Firebase Console](https://console.firebase.google.com)
- [FCM HTTP v1 API Reference](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages)
