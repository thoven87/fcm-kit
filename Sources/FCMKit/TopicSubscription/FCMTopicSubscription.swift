import Foundation

// MARK: - FCMTopicSubscription

/// A subscription of a single device (FID) to a single FCM topic.
///
/// Returned by ``FCMClient/subscribe(fid:to:)``, ``FCMClient/getSubscription(fid:topic:)``,
/// and ``FCMClient/listSubscriptions(fid:pageSize:pageToken:)``.
public struct FCMTopicSubscription: Decodable, Sendable {

    /// Full resource name.
    ///
    /// Format: `projects/{project}/registrations/{fid}/topicSubscriptions/{topic}`
    public let name: String

    /// The topic ID — the last path segment of ``name``. Output only.
    public let topicName: String?

    /// When the subscription was created (RFC 3339). Output only.
    public let createTime: String?

    /// Creates a subscription value directly.
    ///
    /// Use this in ``MockFCMClient`` and other test doubles to construct
    /// stub return values without going through JSON decoding.
    ///
    /// - Parameters:
    ///   - name:       Full resource name.
    ///   - topicName:  Topic ID (last path segment of `name`).
    ///   - createTime: RFC 3339 creation timestamp.
    public init(name: String, topicName: String? = nil, createTime: String? = nil) {
        self.name       = name
        self.topicName  = topicName
        self.createTime = createTime
    }
}

// MARK: - FCMTopicSubscriptionsPage

/// A paginated list of ``FCMTopicSubscription`` results.
///
/// When ``nextPageToken`` is non-nil, pass it to the next
/// ``FCMClient/listSubscriptions(fid:pageSize:pageToken:)`` call to retrieve more.
public struct FCMTopicSubscriptionsPage: Decodable, Sendable {

    /// The subscriptions for this page.
    public let topicSubscriptions: [FCMTopicSubscription]

    /// Token for the next page. `nil` when this is the final page.
    public let nextPageToken: String?

    /// Creates a page value directly.
    ///
    /// Use this in test doubles to return stub paginated results.
    ///
    /// - Parameters:
    ///   - topicSubscriptions: Subscriptions for this page.
    ///   - nextPageToken:      Continuation token; `nil` for the last page.
    public init(topicSubscriptions: [FCMTopicSubscription], nextPageToken: String? = nil) {
        self.topicSubscriptions = topicSubscriptions
        self.nextPageToken      = nextPageToken
    }
}
