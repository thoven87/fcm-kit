// MARK: - FCMServerErrorCode

/// Typed FCM HTTP v1 API error codes returned in the `status` field of an error response.
///
/// When FCM returns a structured error, ``FCMError/serverError(status:code:message:)`` will contain
/// one of these values in its `code` parameter (or `nil` for unrecognised future codes).
///
/// See [FCM Error Codes](https://firebase.google.com/docs/cloud-messaging/error-codes)
/// for full descriptions and recommended resolution steps.
public enum FCMServerErrorCode: String, Sendable {

    /// No information is available about this error.
    case unspecifiedError    = "UNSPECIFIED_ERROR"

    /// Request parameters were invalid (HTTP 400).
    ///
    /// Common causes: malformed registration token, oversized payload (>4 KB for most messages,
    /// >2 KB for topic messages), reserved data keys, or invalid TTL.
    case invalidArgument     = "INVALID_ARGUMENT"

    /// The target device is no longer registered with FCM (HTTP 404).
    ///
    /// Remove the token from your database and stop sending to it.
    case unregistered        = "UNREGISTERED"

    /// The authenticated sender ID differs from the registration token's sender ID (HTTP 403).
    case senderIDMismatch    = "SENDER_ID_MISMATCH"

    /// Sending limit exceeded for the message target (HTTP 429).
    ///
    /// Reduce send rate and retry with exponential back-off (minimum 1-minute initial delay).
    case quotaExceeded       = "QUOTA_EXCEEDED"

    /// The FCM server is overloaded — retry with exponential back-off (HTTP 503).
    ///
    /// Honour the `Retry-After` header if present in the response.
    case unavailable         = "UNAVAILABLE"

    /// An unknown internal error occurred (HTTP 500).
    ///
    /// Retry with the same request, following back-off guidelines.
    case `internal`          = "INTERNAL"

    /// APNs certificate or web-push auth key was invalid or missing (HTTP 401).
    ///
    /// Verify your development and production credentials in the Firebase console.
    case thirdPartyAuthError = "THIRD_PARTY_AUTH_ERROR"
}

// MARK: - FCMError

/// Errors produced by FCMKit.
///
/// All throwing methods in FCMKit throw values of this type. Use a `do/catch` block
/// with pattern matching to handle specific cases:
///
/// ```swift
/// do {
///     try await client.send(message)
/// } catch FCMError.serverError(_, let code, let message) {
///     if code == .unregistered {
///         // remove the token from your database
///     }
/// } catch {
///     print("Unexpected error:", error)
/// }
/// ```
public enum FCMError: Error, Sendable {

    // MARK: Credential / token errors

    /// The service-account JSON was malformed or missing required fields.
    ///
    /// Check that the file downloaded from the Firebase console is intact
    /// and was not truncated.
    case invalidCredentials(String)

    /// Signing a JWT or exchanging it for an OAuth 2.0 access token failed.
    ///
    /// Verify your service account has the **Firebase Cloud Messaging API** role
    /// and that the private key in the JSON file has not been revoked.
    case tokenGenerationFailed(String)

    // MARK: Send errors

    /// The FCM server returned a structured error response.
    ///
    /// - `status`: HTTP status code (e.g. 400, 404, 429).
    /// - `code`: Typed ``FCMServerErrorCode`` when recognised; `nil` for future codes.
    /// - `message`: Human-readable description from FCM.
    case serverError(status: Int, code: FCMServerErrorCode?, message: String)

    /// The server returned a non-200 response with an unstructured body.
    ///
    /// This is a fallback when the response body cannot be parsed as a structured FCM error.
    case httpError(status: Int, body: String)

    // MARK: Coding errors

    /// Encoding the outbound message failed.
    ///
    /// This should not occur with well-formed FCMKit types. If you encounter it,
    /// check that all custom payload values are valid JSON.
    case encodingFailed

    /// Decoding a response body failed.
    case decodingFailed(String)

    /// The response body was missing expected fields.
    ///
    /// This can happen if the FCM API schema changes in a way not yet reflected
    /// in FCMKit. Please file an issue.
    case invalidResponse
}
