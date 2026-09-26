import Foundation
import AsyncHTTPClient
import NIOCore

// MARK: - FCMClient

/// The main FCM client.
///
/// Create once and reuse across your application.
///
/// **Outside GCP** (local dev, non-Google cloud) — use a service-account JSON key:
///
/// ```swift
/// let account = try ServiceAccount.load(contentsOfFile: "/secrets/sa.json")
/// let client  = try FCMClient(
///     credentials: account,
///     httpClient:  .shared,
///     decoder:     JSONDecoder(),
///     encoder:     JSONEncoder()
/// )
/// ```
///
/// **On GCP** (Cloud Run, GCE, GKE) — use Application Default Credentials.
/// No key files needed; the platform provides the identity:
///
/// ```swift
/// let client = FCMClient(
///     projectID:  ProcessInfo.processInfo.environment["FCM_PROJECT_ID"]!,
///     httpClient: .shared,
///     decoder:    JSONDecoder(),
///     encoder:    JSONEncoder()
/// )
/// ```
public final class FCMClient<Decoder: FCMJSONDecoder, Encoder: FCMJSONEncoder>: Sendable {

    // MARK: - Dependencies
    //
    // Properties are `internal` so that extension files in this module
    // (e.g. FCMClient+TopicSubscriptions) can access them without duplication.

    let httpClient:          HTTPClient
    let tokenProvider:       any TokenProviding
    let decoder:             Decoder
    let encoder:             Encoder
    let byteBufferAllocator: ByteBufferAllocator
    let configuration:       FCMConfiguration

    /// Firebase project ID, e.g. `"my-project"`.
    let projectID:            String

    /// Base URL for registration/subscription management.
    /// `https://fcm.googleapis.com/v1/projects/{projectID}/registrations`
    let registrationsBaseURL: String

    let sendURL: String

    // MARK: - Init

    /// Creates a new FCM client.
    ///
    /// - Parameters:
    ///   - credentials:          Decoded service-account credentials.
    ///   - httpClient:           `HTTPClient` used for all requests. Pass `HTTPClient.shared`
    ///                           for the process-wide singleton (recommended), or supply your
    ///                           own instance if you need custom TLS or proxy settings.
    ///                           The caller is responsible for shutting down any non-shared client.
    ///   - decoder:              Decoder used for every FCM response body. `JSONDecoder()` works out of the box.
    ///   - encoder:              Encoder used for every FCM request body. `JSONEncoder()` works out of the box.
    ///   - byteBufferAllocator:  Allocator for request `ByteBuffer`s (default: `.init()`).
    ///   - configuration:        Timeout and size tuning (default: ``FCMConfiguration/default``).
    /// - Throws: ``FCMError/invalidCredentials(_:)`` if the private key in `credentials` is malformed.
    public init(
        credentials:         ServiceAccount,
        httpClient:          HTTPClient,
        decoder:             Decoder,
        encoder:             Encoder,
        byteBufferAllocator: ByteBufferAllocator = .init(),
        configuration:       FCMConfiguration   = .default
    ) throws {
        let pid                   = credentials.projectID
        self.httpClient           = httpClient
        self.decoder              = decoder
        self.encoder              = encoder
        self.byteBufferAllocator  = byteBufferAllocator
        self.configuration        = configuration
        self.projectID            = pid
        self.registrationsBaseURL = "https://fcm.googleapis.com/v1/projects/\(pid)/registrations"
        self.sendURL              = "https://fcm.googleapis.com/v1/projects/\(pid)/messages:send"
        self.tokenProvider        = try ServiceAccountTokenProvider(
            credentials: credentials,
            httpClient:  httpClient,
            decoder:     decoder as any FCMJSONDecoder
        )
    }

    /// Creates a client using **Application Default Credentials (ADC)**.
    ///
    /// On Google Cloud Platform (Cloud Run, GCE, GKE, etc.) every instance has an
    /// attached service account. ADC fetches a Bearer token from the local GCP metadata
    /// server — no credential files, no JWT signing, no `throws`.
    ///
    /// ```swift
    /// // Cloud Run — read project ID from env and use ADC
    /// let projectID = ProcessInfo.processInfo.environment["FCM_PROJECT_ID"]!
    /// let client    = FCMClient(
    ///     projectID:  projectID,
    ///     httpClient: .shared,
    ///     decoder:    JSONDecoder(),
    ///     encoder:    JSONEncoder()
    /// )
    /// ```
    ///
    /// > Important: The GCP metadata server (`http://metadata.google.internal`) is only
    /// > reachable from within GCP. For local development, use the service-account
    /// > ``init(credentials:httpClient:decoder:encoder:byteBufferAllocator:configuration:)``
    /// > initialiser instead.
    ///
    /// - Parameters:
    ///   - projectID:            Firebase project ID. Typically set as `FCM_PROJECT_ID` in the
    ///                           Cloud Run service's environment variables.
    ///   - httpClient:           `HTTPClient` for all requests. Pass `.shared` (recommended).
    ///   - decoder:              Decoder for response bodies.
    ///   - encoder:              Encoder for request bodies.
    ///   - byteBufferAllocator:  Allocator for request buffers (default: `.init()`).
    ///   - configuration:        Timeout and size tuning (default: ``FCMConfiguration/default``).
    ///   - serviceAccountEmail:  Override the default service account. Pass `nil` to use
    ///                           the instance's default identity (recommended).
    public init(
        projectID:           String,
        httpClient:          HTTPClient,
        decoder:             Decoder,
        encoder:             Encoder,
        byteBufferAllocator: ByteBufferAllocator = .init(),
        configuration:       FCMConfiguration   = .default,
        serviceAccountEmail: String?            = nil
    ) {
        self.httpClient           = httpClient
        self.decoder              = decoder
        self.encoder              = encoder
        self.byteBufferAllocator  = byteBufferAllocator
        self.configuration        = configuration
        self.projectID            = projectID
        self.registrationsBaseURL = "https://fcm.googleapis.com/v1/projects/\(projectID)/registrations"
        self.sendURL              = "https://fcm.googleapis.com/v1/projects/\(projectID)/messages:send"
        self.tokenProvider        = ADCTokenProvider(
            httpClient:          httpClient,
            decoder:             decoder as any FCMJSONDecoder,
            serviceAccountEmail: serviceAccountEmail
        )
    }

    // MARK: - Send

    /// Sends a single FCM message.
    ///
    /// - Parameters:
    ///   - message:      The message to send.
    ///   - validateOnly: When `true` the message is validated by FCM but **not** delivered.
    ///                   Useful for smoke tests and CI pipelines.
    /// - Returns: The FCM message name, e.g.
    ///   `"projects/my-project/messages/0:1234567890%device-token"`.
    /// - Throws: ``FCMError/serverError(status:code:message:)`` for FCM-level errors,
    ///   ``FCMError/tokenGenerationFailed(_:)`` if OAuth token refresh fails,
    ///   or ``FCMError/httpError(status:body:)`` for unexpected non-200 responses.
    @discardableResult
    public func send(_ message: FCMMessage, validateOnly: Bool = false) async throws -> String {
        let token = try await tokenProvider.validToken()
        return try await execute(token: token, message: message, validateOnly: validateOnly)
    }

    /// Sends multiple messages concurrently and returns results in input order.
    ///
    /// The OAuth token is fetched once before any tasks are spawned. Individual
    /// send failures are captured as `.failure` entries so one bad token doesn't
    /// abort the whole batch.
    ///
    /// - Parameter messages: Messages to send concurrently. Order is preserved in the result.
    /// - Returns: `[Result<String, any Error>]` aligned with `messages`.
    /// - Throws: ``FCMError/tokenGenerationFailed(_:)`` if the OAuth token cannot be obtained
    ///   before task spawning begins. Individual send errors are captured in each `Result`.
    public func sendBatch(_ messages: [FCMMessage]) async throws -> [Result<String, any Error>] {
        guard !messages.isEmpty else { return [] }

        let token = try await tokenProvider.validToken()

        return try await withThrowingTaskGroup(of: (Int, Result<String, any Error>).self) { group in
            for (index, message) in messages.enumerated() {
                group.addTask {
                    do {
                        let name = try await self.execute(token: token, message: message)
                        return (index, .success(name))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }

            var results = [Result<String, any Error>](
                repeating: .failure(FCMError.invalidResponse),
                count: messages.count
            )
            for try await (index, result) in group {
                results[index] = result
            }
            return results
        }
    }

    // MARK: - Internal helpers (available to module extensions)

    /// Builds an ``FCMError`` from an HTTP error status and raw response buffer.
    ///
    /// Tries to parse a structured FCM error body first; falls back to a raw `httpError`.
    func buildError(status: Int, buffer: ByteBuffer) -> FCMError {
        if let body = try? decoder.decode(FCMAPIErrorBody.self, from: buffer) {
            return .serverError(
                status:  status,
                code:    FCMServerErrorCode(rawValue: body.error.status ?? ""),
                message: body.error.message
            )
        }
        var copy = buffer
        let text = copy.readString(length: buffer.readableBytes) ?? ""
        return .httpError(status: status, body: text)
    }

    /// Encodes a value into an existing `ByteBuffer` using the client's encoder.
    func encode<T: Encodable>(_ value: T, into buffer: inout ByteBuffer) throws {
        do {
            try encoder.encode(value, into: &buffer)
        } catch {
            throw FCMError.encodingFailed
        }
    }

    // MARK: - Private

    private func execute(
        token:        String,
        message:      FCMMessage,
        validateOnly: Bool = false
    ) async throws -> String {
        var buffer = byteBufferAllocator.buffer(capacity: 256)
        try encodeRequest(message: message, validateOnly: validateOnly, into: &buffer)

        var req = HTTPClientRequest(url: sendURL)
        req.method = .POST
        req.headers.add(name: "Authorization", value: "Bearer \(token)")
        req.headers.add(name: "Content-Type",  value: "application/json; charset=utf-8")
        req.body = .bytes(buffer)

        let response = try await httpClient.execute(req, timeout: configuration.requestTimeoutAmount)
        return try await parseSendResponse(response)
    }

    private func encodeRequest(message: FCMMessage, validateOnly: Bool, into buffer: inout ByteBuffer) throws {
        let wrapper = SendRequest(validateOnly: validateOnly ? true : nil, message: message)
        try encode(wrapper, into: &buffer)
    }

    /// Parses a `messages:send` response — shared by regular sends and Live Activity sends.
    func parseSendResponse(_ response: HTTPClientResponse) async throws -> String {
        let buffer = try await response.body.collect(upTo: configuration.maxResponseSize)

        if response.status.code == 200 {
            guard let result = try? decoder.decode(SendResponse.self, from: buffer) else {
                throw FCMError.invalidResponse
            }
            return result.name
        }

        throw buildError(status: Int(response.status.code), buffer: buffer)
    }
}

// MARK: - Private wire types

private struct SendRequest: Encodable {
    let validateOnly: Bool?
    let message:      FCMMessage

    private enum CodingKeys: String, CodingKey {
        case validateOnly = "validate_only"
        case message
    }
}

private struct SendResponse: Decodable {
    let name: String
}

// FCMAPIErrorBody is also used by buildError, which is called from extensions.
// Keeping it private here is intentional — extensions use buildError, not the struct directly.
private struct FCMAPIErrorBody: Decodable {
    struct Detail: Decodable {
        let code:    Int
        let message: String
        let status:  String?
    }
    let error: Detail
}
