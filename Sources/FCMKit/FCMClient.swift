import Foundation
import AsyncHTTPClient
import NIOCore

// MARK: - FCMClient

/// The main FCM client.
///
/// Create once and reuse across your application. The caller owns the
/// `HTTPClient` and is responsible for its lifecycle.
///
/// ```swift
/// let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
/// let account    = try ServiceAccount.load(contentsOfFile: "/secrets/sa.json")
///
/// let client = try FCMClient(
///     credentials: account,
///     httpClient:  httpClient,
///     decoder:     JSONDecoder(),
///     encoder:     JSONEncoder()
/// )
///
/// let id = try await client.send(
///     FCMMessage(target: .token(deviceToken),
///                notification: FCMNotification(title: "Hello", body: "World"))
/// )
/// ```
public final class FCMClient<Decoder: FCMJSONDecoder, Encoder: FCMJSONEncoder>: Sendable {

    // MARK: - Dependencies

    private let httpClient:          HTTPClient
    private let tokenProvider:       TokenProvider
    private let decoder:             Decoder
    private let encoder:             Encoder
    private let byteBufferAllocator: ByteBufferAllocator
    private let sendURL:             String
    private let configuration:       FCMConfiguration

    // MARK: - Init

    /// Creates a new FCM client.
    ///
    /// - Parameters:
    ///   - credentials:          Decoded service-account credentials.
    ///   - httpClient:           Shared `HTTPClient` for all requests. The caller owns it.
    ///   - decoder:              Decoder used for every FCM response body.
    ///   - encoder:              Encoder used for every FCM request body.
    ///   - byteBufferAllocator:  Allocator for request `ByteBuffer`s (default: `.init()`).
    ///   - configuration:        Timeout and size tuning (default: ``FCMConfiguration/default``).
    public init(
        credentials:         ServiceAccount,
        httpClient:          HTTPClient,
        decoder:             Decoder,
        encoder:             Encoder,
        byteBufferAllocator: ByteBufferAllocator = .init(),
        configuration:       FCMConfiguration   = .default
    ) throws {
        self.httpClient          = httpClient
        self.decoder             = decoder
        self.encoder             = encoder
        self.byteBufferAllocator = byteBufferAllocator
        self.configuration       = configuration
        self.tokenProvider       = try TokenProvider(
            credentials: credentials,
            httpClient:  httpClient,
            decoder:     decoder as any FCMJSONDecoder
        )
        self.sendURL = "https://fcm.googleapis.com/v1/projects/\(credentials.projectID)/messages:send"
    }

    // MARK: - Send

    /// Sends a single FCM message.
    ///
    /// - Parameters:
    ///   - message:      The message to send.
    ///   - validateOnly: When `true` the message is validated by FCM but **not** delivered.
    /// - Returns: The FCM message name, e.g.
    ///   `"projects/my-project/messages/0:1234567890%device-token"`.
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
    /// - Returns: `[Result<String, any Error>]` aligned with `messages`.
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
        return try await parseResponse(response)
    }

    private func encodeRequest(
        message:      FCMMessage,
        validateOnly: Bool,
        into buffer:  inout ByteBuffer
    ) throws {
        let wrapper = SendRequest(validateOnly: validateOnly ? true : nil, message: message)
        do {
            try encoder.encode(wrapper, into: &buffer)
        } catch {
            throw FCMError.encodingFailed
        }
    }

    private func parseResponse(_ response: HTTPClientResponse) async throws -> String {
        let buffer = try await response.body.collect(upTo: configuration.maxResponseSize)

        if response.status.code == 200 {
            guard let result = try? decoder.decode(SendResponse.self, from: buffer) else {
                throw FCMError.invalidResponse
            }
            return result.name
        }

        if let fcmError = try? decoder.decode(FCMAPIErrorBody.self, from: buffer) {
            throw FCMError.serverError(
                status:    Int(response.status.code),
                fcmStatus: fcmError.error.status ?? "",
                message:   fcmError.error.message
            )
        }

        var copy = buffer
        let body = copy.readString(length: buffer.readableBytes) ?? ""
        throw FCMError.httpError(status: Int(response.status.code), body: body)
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

private struct FCMAPIErrorBody: Decodable {
    struct Detail: Decodable {
        let code:    Int
        let message: String
        let status:  String?
    }
    let error: Detail
}
