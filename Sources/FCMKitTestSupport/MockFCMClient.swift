import FCMKit
import Foundation

// MARK: - MockFCMClient

/// A test double for ``FCMClientProtocol`` that records calls and returns
/// configurable stub values without making any real network requests.
///
/// Import `FCMKitTestSupport` in your test target and inject `MockFCMClient`
/// wherever production code depends on `any FCMClientProtocol`:
///
/// ```swift
/// import Testing
/// import FCMKit
/// import FCMKitTestSupport
///
/// @Suite("NotificationService")
/// struct NotificationServiceTests {
///
///     @Test("sends the correct message")
///     func sendsCorrectMessage() async throws {
///         let mock    = MockFCMClient()
///         let service = NotificationService(fcm: mock)
///
///         try await service.notify(token: "abc", title: "Hi", body: "World")
///
///         #expect(mock.sendCount == 1)
///         #expect(mock.lastSentMessage?.notification?.title == "Hi")
///     }
///
///     @Test("propagates errors")
///     func propagatesErrors() async throws {
///         let mock    = MockFCMClient()
///         mock.nextSendError = FCMError.serverError(
///             status: 404, code: .unregistered, message: "Gone"
///         )
///         await #expect(throws: FCMError.self) {
///             try await mock.send(FCMMessage(target: .fid("t")))
///         }
///     }
/// }
/// ```
///
/// Properties are directly assignable — no `await` needed:
///
/// ```swift
/// mock.nextSendError   = FCMError.serverError(...)   // throw on next send
/// mock.stubbedMessageID = "projects/p/messages/42"   // control return value
/// ```
public final class MockFCMClient: FCMClientProtocol, @unchecked Sendable {

    // MARK: - Recorded calls

    /// Every message passed to ``send(_:validateOnly:)`` or included in ``sendBatch(_:)``.
    public private(set) var sentMessages: [FCMMessage] = []

    /// Arguments passed to ``subscribe(fid:to:)`` and ``createSubscription(fid:to:)``,
    /// in call order.
    public private(set) var subscribeCalls: [(fid: String, topic: String)] = []

    /// Arguments passed to ``unsubscribe(fid:from:)``, in call order.
    public private(set) var unsubscribeCalls: [(fid: String, topic: String)] = []

    // MARK: - Stubs

    /// Error thrown by the next ``send(_:validateOnly:)`` call.
    /// Cleared automatically after it is thrown once.
    public var nextSendError: (any Error)?

    /// Error thrown by the next ``sendBatch(_:)`` call.
    /// Cleared automatically after it is thrown once.
    public var nextBatchError: (any Error)?

    /// Error thrown by the next topic-subscription call.
    /// Cleared automatically after it is thrown once.
    public var nextSubscriptionError: (any Error)?

    /// Message name returned by ``send(_:validateOnly:)`` and ``sendBatch(_:)``.
    /// Default: `"projects/test/messages/mock-id"`.
    public var stubbedMessageID = "projects/test/messages/mock-id"

    /// Subscription returned by ``subscribe(fid:to:)``, ``createSubscription(fid:to:)``,
    /// and ``getSubscription(fid:topic:)``.
    public var stubbedSubscription = FCMTopicSubscription(
        name:      "projects/test/registrations/mock-fid/topicSubscriptions/mock-topic",
        topicName: "mock-topic"
    )

    /// Page returned by ``listSubscriptions(fid:pageSize:pageToken:)``.
    public var stubbedPage = FCMTopicSubscriptionsPage(topicSubscriptions: [])

    public init() {}

    // MARK: - Helpers

    /// The last message passed to a send call, or `nil` if nothing has been sent yet.
    public var lastSentMessage: FCMMessage? { sentMessages.last }

    /// Total number of individual messages recorded across all send calls.
    public var sendCount: Int { sentMessages.count }

    /// Resets all recorded calls and pending errors, returning the mock to its initial state.
    public func reset() {
        sentMessages.removeAll()
        subscribeCalls.removeAll()
        unsubscribeCalls.removeAll()
        nextSendError         = nil
        nextBatchError        = nil
        nextSubscriptionError = nil
    }

    // MARK: - FCMClientProtocol

    public func send(_ message: FCMMessage, validateOnly: Bool) async throws -> String {
        if let error = nextSendError {
            nextSendError = nil
            throw error
        }
        sentMessages.append(message)
        return stubbedMessageID
    }

    public func sendBatch(_ messages: [FCMMessage]) async throws -> [Result<String, any Error>] {
        if let error = nextBatchError {
            nextBatchError = nil
            throw error
        }
        sentMessages.append(contentsOf: messages)
        return messages.map { _ in .success(stubbedMessageID) }
    }

    public func createSubscription(fid: String, to topic: String) async throws -> FCMTopicSubscription {
        if let error = nextSubscriptionError {
            nextSubscriptionError = nil
            throw error
        }
        subscribeCalls.append((fid: fid, topic: topic))
        return stubbedSubscription
    }

    public func subscribe(fid: String, to topic: String) async throws -> FCMTopicSubscription {
        if let error = nextSubscriptionError {
            nextSubscriptionError = nil
            throw error
        }
        subscribeCalls.append((fid: fid, topic: topic))
        return stubbedSubscription
    }

    public func unsubscribe(fid: String, from topic: String) async throws {
        if let error = nextSubscriptionError {
            nextSubscriptionError = nil
            throw error
        }
        unsubscribeCalls.append((fid: fid, topic: topic))
    }

    public func getSubscription(fid: String, topic: String) async throws -> FCMTopicSubscription {
        if let error = nextSubscriptionError {
            nextSubscriptionError = nil
            throw error
        }
        return stubbedSubscription
    }

    public func listSubscriptions(
        fid:       String,
        pageSize:  Int,
        pageToken: String?
    ) async throws -> FCMTopicSubscriptionsPage {
        if let error = nextSubscriptionError {
            nextSubscriptionError = nil
            throw error
        }
        return stubbedPage
    }
}
