import Foundation
import AsyncHTTPClient
import NIOCore

// MARK: - Topic Subscription Management

extension FCMClient {

    // MARK: - Create (strict)

    /// Creates a new topic subscription.
    ///
    /// Unlike ``subscribe(fid:to:)``, this call **fails** if the device is already
    /// subscribed — FCM returns ``FCMServerErrorCode/invalidArgument`` with an
    /// `ALREADY_EXISTS` detail. Prefer ``subscribe(fid:to:)`` for idempotent behaviour.
    ///
    /// - Parameters:
    ///   - fid:   Firebase Installation ID or FCM registration token.
    ///   - topic: Topic name without the `/topics/` prefix.
    /// - Returns: The newly created ``FCMTopicSubscription``.
    /// - Throws: ``FCMError/serverError(status:code:message:)`` when the subscription
    ///   already exists or arguments are invalid.
    @discardableResult
    public func createSubscription(fid: String, to topic: String) async throws -> FCMTopicSubscription {
        let url  = "\(registrationsBaseURL)/\(fid)/topicSubscriptions?topicName=\(topic)"
        let body = TopicSubscriptionBody(name: resourceName(fid: fid, topic: topic))
        let tok  = try await tokenProvider.validToken()

        var buf = byteBufferAllocator.buffer(capacity: 128)
        try encode(body, into: &buf)

        var req = HTTPClientRequest(url: url)
        req.method = .POST
        req.headers.add(name: "Authorization", value: "Bearer \(tok)")
        req.headers.add(name: "Content-Type",  value: "application/json; charset=utf-8")
        req.body = .bytes(buf)

        let response = try await httpClient.execute(req, timeout: configuration.requestTimeoutAmount)
        return try await decodeBody(from: response)
    }

    // MARK: - Subscribe (upsert)

    /// Subscribes a device to a topic.
    ///
    /// This call is idempotent — if the device is already subscribed, the existing
    /// ``FCMTopicSubscription`` is returned without error.
    ///
    /// ```swift
    /// let sub = try await client.subscribe(fid: deviceToken, to: "breaking-news")
    /// print(sub.createTime ?? "")
    /// ```
    ///
    /// - Parameters:
    ///   - fid:   Firebase Installation ID or FCM registration token.
    ///   - topic: Topic name without the `/topics/` prefix.
    /// - Returns: The ``FCMTopicSubscription`` (new or existing).
    /// - Throws: ``FCMError`` if the network request or token refresh fails.
    @discardableResult
    public func subscribe(fid: String, to topic: String) async throws -> FCMTopicSubscription {
        // PATCH with allowMissing=true is an idempotent upsert.
        let url  = subscriptionURL(fid: fid, topic: topic) + "?allowMissing=true"
        let body = TopicSubscriptionBody(name: resourceName(fid: fid, topic: topic))
        let tok  = try await tokenProvider.validToken()

        var buf = byteBufferAllocator.buffer(capacity: 128)
        try encode(body, into: &buf)

        var req = HTTPClientRequest(url: url)
        req.method = .PATCH
        req.headers.add(name: "Authorization", value: "Bearer \(tok)")
        req.headers.add(name: "Content-Type",  value: "application/json; charset=utf-8")
        req.body = .bytes(buf)

        let response = try await httpClient.execute(req, timeout: configuration.requestTimeoutAmount)
        return try await decodeBody(from: response)
    }

    // MARK: - Unsubscribe

    /// Unsubscribes a device from a topic.
    ///
    /// This call is idempotent — if the device is not subscribed, no error is returned.
    ///
    /// - Parameters:
    ///   - fid:   Firebase Installation ID or FCM registration token.
    ///   - topic: Topic name without the `/topics/` prefix.
    /// - Throws: ``FCMError`` if the network request or token refresh fails.
    public func unsubscribe(fid: String, from topic: String) async throws {
        let url = subscriptionURL(fid: fid, topic: topic) + "?allowMissing=true"
        let tok = try await tokenProvider.validToken()

        var req = HTTPClientRequest(url: url)
        req.method = .DELETE
        req.headers.add(name: "Authorization", value: "Bearer \(tok)")

        let response = try await httpClient.execute(req, timeout: configuration.requestTimeoutAmount)
        try await drainAndCheck(response)
    }

    // MARK: - Get

    /// Returns the subscription for a specific device and topic.
    ///
    /// Throws ``FCMError/serverError(status:code:message:)`` with
    /// ``FCMServerErrorCode/unregistered`` if the subscription does not exist.
    ///
    /// - Parameters:
    ///   - fid:   Firebase Installation ID or FCM registration token.
    ///   - topic: Topic name without the `/topics/` prefix.
    /// - Returns: The ``FCMTopicSubscription`` for this device/topic pair.
    /// - Throws: ``FCMError/serverError(status:code:message:)`` with
    ///   ``FCMServerErrorCode/unregistered`` if the subscription does not exist.
    public func getSubscription(fid: String, topic: String) async throws -> FCMTopicSubscription {
        let url = subscriptionURL(fid: fid, topic: topic)
        let tok = try await tokenProvider.validToken()

        var req = HTTPClientRequest(url: url)
        req.method = .GET
        req.headers.add(name: "Authorization", value: "Bearer \(tok)")

        let response = try await httpClient.execute(req, timeout: configuration.requestTimeoutAmount)
        return try await decodeBody(from: response)
    }

    // MARK: - List

    /// Lists all topic subscriptions for a device.
    ///
    /// Results are paginated. When ``FCMTopicSubscriptionsPage/nextPageToken`` is non-nil,
    /// pass it as `pageToken` to retrieve the next page.
    ///
    /// ```swift
    /// var pageToken: String? = nil
    /// repeat {
    ///     let page = try await client.listSubscriptions(fid: deviceToken, pageToken: pageToken)
    ///     page.topicSubscriptions.forEach { print($0.topicName ?? "") }
    ///     pageToken = page.nextPageToken
    /// } while pageToken != nil
    /// ```
    ///
    /// - Parameters:
    ///   - fid:       Firebase Installation ID or FCM registration token.
    ///   - pageSize:  Maximum results per page (default: 1 000, maximum: 2 000).
    ///   - pageToken: Continuation token from a previous call; `nil` for the first page.
    /// - Returns: A ``FCMTopicSubscriptionsPage`` with the subscriptions and an optional continuation token.
    /// - Throws: ``FCMError`` if the network request or token refresh fails.
    public func listSubscriptions(
        fid:       String,
        pageSize:  Int     = 1_000,
        pageToken: String? = nil
    ) async throws -> FCMTopicSubscriptionsPage {
        var url = "\(registrationsBaseURL)/\(fid)/topicSubscriptions?pageSize=\(pageSize)"
        if let pt = pageToken { url += "&pageToken=\(pt)" }

        let tok = try await tokenProvider.validToken()

        var req = HTTPClientRequest(url: url)
        req.method = .GET
        req.headers.add(name: "Authorization", value: "Bearer \(tok)")

        let response = try await httpClient.execute(req, timeout: configuration.requestTimeoutAmount)
        return try await decodeBody(from: response)
    }

    // MARK: - Private helpers

    private func subscriptionURL(fid: String, topic: String) -> String {
        "\(registrationsBaseURL)/\(fid)/topicSubscriptions/\(topic)"
    }

    private func resourceName(fid: String, topic: String) -> String {
        "projects/\(projectID)/registrations/\(fid)/topicSubscriptions/\(topic)"
    }

    /// Collects the response body, checks the status, and decodes to `T`.
    private func decodeBody<T: Decodable>(from response: HTTPClientResponse) async throws -> T {
        let buffer = try await response.body.collect(upTo: configuration.maxResponseSize)

        guard (200...299).contains(Int(response.status.code)) else {
            throw buildError(status: Int(response.status.code), buffer: buffer)
        }

        guard let result = try? decoder.decode(T.self, from: buffer) else {
            throw FCMError.invalidResponse
        }
        return result
    }

    /// Drains the response body and throws on non-2xx status (used for DELETE).
    private func drainAndCheck(_ response: HTTPClientResponse) async throws {
        // Collect up to a small limit — successful DELETEs return an empty body.
        let buffer = try await response.body.collect(upTo: 4_096)

        guard (200...299).contains(Int(response.status.code)) else {
            throw buildError(status: Int(response.status.code), buffer: buffer)
        }
    }
}

// MARK: - Private wire type

/// Request body for PATCH (upsert) subscription calls.
private struct TopicSubscriptionBody: Encodable {
    /// Full resource name: `projects/{project}/registrations/{fid}/topicSubscriptions/{topic}`.
    let name: String
}
