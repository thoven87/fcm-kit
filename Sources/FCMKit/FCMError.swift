/// Errors produced by FCMKit.
public enum FCMError: Error, Sendable {

    // MARK: Credential / token errors

    /// The service-account JSON was malformed or missing required fields.
    case invalidCredentials(String)

    /// Signing a JWT or exchanging it for an OAuth token failed.
    case tokenGenerationFailed(String)

    // MARK: Send errors

    /// The FCM server returned a structured error response.
    case serverError(status: Int, fcmStatus: String, message: String)

    /// The server returned a non-200 response with an unstructured body.
    case httpError(status: Int, body: String)

    // MARK: Coding errors

    /// Encoding the outbound message failed.
    case encodingFailed

    /// Decoding a response body failed.
    case decodingFailed(String)

    /// The response body was missing expected fields.
    case invalidResponse
}
