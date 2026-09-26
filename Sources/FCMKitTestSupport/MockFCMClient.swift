import FCMKit
import Foundation
import Synchronization

// MARK: - MockFCMClient

/// A thread-safe test double for ``FCMClientProtocol`` that records calls and
/// returns configurable stub values without making any real network requests.
///
/// `MockFCMClient` is a `final class` whose mutable state is protected by a
/// `Mutex` from the Swift `Synchronization` module, making it safe to share
/// across concurrent test tasks. The mutex is held only for synchronous
/// reads and writes — never across an `async` suspension point.
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
/// Stub properties are directly assignable — no `await` required:
///
/// ```swift
/// mock.nextSendError    = FCMError.serverError(...)   // throw on next send
/// mock.stubbedMessageID = "projects/p/messages/42"   // control return value
/// ```
public final class MockFCMClient: FCMClientProtocol, Sendable {

    // MARK: - Protected state

    private struct State: Sendable {
        var sentMessages:          [FCMMessage]                   = []
        var subscribeCalls:        [(fid: String, topic: String)] = []
        var unsubscribeCalls:      [(fid: String, topic: String)] = []
        var nextSendError:         (any Error)?
        var nextBatchError:        (any Error)?
        var nextSubscriptionError: (any Error)?
        var stubbedMessageID     = "projects/test/messages/mock-id"
        var stubbedSubscription  = FCMTopicSubscription(
            name:      "projects/test/registrations/mock-fid/topicSubscriptions/mock-topic",
            topicName: "mock-topic"
        )
        var stubbedPage = FCMTopicSubscriptionsPage(topicSubscriptions: [])
    }

    private let _state: Mutex<State>

    // MARK: - Init

    public init() {
        _state = Mutex(State())
    }

    // MARK: - Recorded calls

    /// Every message passed to ``send(_:validateOnly:)`` or ``sendBatch(_:)``.
    public var sentMessages: [FCMMessage] {
        _state.withLock { $0.sentMessages }
    }

    /// Arguments passed to ``subscribe(fid:to:)`` and ``createSubscription(fid:to:)``.
    public var subscribeCalls: [(fid: String, topic: String)] {
        _state.withLock { $0.subscribeCalls }
    }

    /// Arguments passed to ``unsubscribe(fid:from:)``.
    public var unsubscribeCalls: [(fid: String, topic: String)] {
        _state.withLock { $0.unsubscribeCalls }
    }

    // MARK: - Stubs

    /// Error thrown by the next ``send(_:validateOnly:)`` call.
    /// Cleared automatically after it is thrown once.
    public var nextSendError: (any Error)? {
        get { _state.withLock { $0.nextSendError } }
        set { _state.withLock { $0.nextSendError = newValue } }
    }

    /// Error thrown by the next ``sendBatch(_:)`` call.
    /// Cleared automatically after it is thrown once.
    public var nextBatchError: (any Error)? {
        get { _state.withLock { $0.nextBatchError } }
        set { _state.withLock { $0.nextBatchError = newValue } }
    }

    /// Error thrown by the next topic-subscription call.
    /// Cleared automatically after it is thrown once.
    public var nextSubscriptionError: (any Error)? {
        get { _state.withLock { $0.nextSubscriptionError } }
        set { _state.withLock { $0.nextSubscriptionError = newValue } }
    }

    /// Message name returned by send calls. Default: `"projects/test/messages/mock-id"`.
    public var stubbedMessageID: String {
        get { _state.withLock { $0.stubbedMessageID } }
        set { _state.withLock { $0.stubbedMessageID = newValue } }
    }

    /// Subscription returned by subscribe / get / create calls.
    public var stubbedSubscription: FCMTopicSubscription {
        get { _state.withLock { $0.stubbedSubscription } }
        set { _state.withLock { $0.stubbedSubscription = newValue } }
    }

    /// Page returned by list calls.
    public var stubbedPage: FCMTopicSubscriptionsPage {
        get { _state.withLock { $0.stubbedPage } }
        set { _state.withLock { $0.stubbedPage = newValue } }
    }

    // MARK: - Helpers

    /// The last message passed to a send call, or `nil` if nothing has been sent yet.
    public var lastSentMessage: FCMMessage? { sentMessages.last }

    /// Total number of individual messages recorded across all send calls.
    public var sendCount: Int { sentMessages.count }

    /// Resets all recorded calls and pending errors to their initial state.
    public func reset() {
        _state.withLock { $0 = State() }
    }

    // MARK: - FCMClientProtocol

    public func send(_ message: FCMMessage, validateOnly: Bool) async throws -> String {
        let result = _state.withLock { s -> Result<String, any Error> in
            if let e = s.nextSendError { s.nextSendError = nil; return .failure(e) }
            s.sentMessages.append(message)
            return .success(s.stubbedMessageID)
        }
        return try result.get()
    }

    public func sendBatch(_ messages: [FCMMessage]) async throws -> [Result<String, any Error>] {
        let result = _state.withLock { s -> Result<String, any Error> in
            if let e = s.nextBatchError { s.nextBatchError = nil; return .failure(e) }
            s.sentMessages.append(contentsOf: messages)
            return .success(s.stubbedMessageID)
        }
        let id = try result.get()
        return messages.map { _ in .success(id) }
    }

    public func createSubscription(fid: String, to topic: String) async throws -> FCMTopicSubscription {
        let result = _state.withLock { s -> Result<FCMTopicSubscription, any Error> in
            if let e = s.nextSubscriptionError { s.nextSubscriptionError = nil; return .failure(e) }
            s.subscribeCalls.append((fid: fid, topic: topic))
            return .success(s.stubbedSubscription)
        }
        return try result.get()
    }

    public func subscribe(fid: String, to topic: String) async throws -> FCMTopicSubscription {
        let result = _state.withLock { s -> Result<FCMTopicSubscription, any Error> in
            if let e = s.nextSubscriptionError { s.nextSubscriptionError = nil; return .failure(e) }
            s.subscribeCalls.append((fid: fid, topic: topic))
            return .success(s.stubbedSubscription)
        }
        return try result.get()
    }

    public func unsubscribe(fid: String, from topic: String) async throws {
        let error = _state.withLock { s -> (any Error)? in
            if let e = s.nextSubscriptionError { s.nextSubscriptionError = nil; return e }
            s.unsubscribeCalls.append((fid: fid, topic: topic))
            return nil
        }
        if let error { throw error }
    }

    public func getSubscription(fid: String, topic: String) async throws -> FCMTopicSubscription {
        let result = _state.withLock { s -> Result<FCMTopicSubscription, any Error> in
            if let e = s.nextSubscriptionError { s.nextSubscriptionError = nil; return .failure(e) }
            return .success(s.stubbedSubscription)
        }
        return try result.get()
    }

    public func listSubscriptions(
        fid:       String,
        pageSize:  Int,
        pageToken: String?
    ) async throws -> FCMTopicSubscriptionsPage {
        let result = _state.withLock { s -> Result<FCMTopicSubscriptionsPage, any Error> in
            if let e = s.nextSubscriptionError { s.nextSubscriptionError = nil; return .failure(e) }
            return .success(s.stubbedPage)
        }
        return try result.get()
    }
}
