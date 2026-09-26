import Foundation
import AsyncHTTPClient
import NIOCore

/// OAuth 2.0 token provider that uses the **GCP metadata server**.
///
/// On Google Cloud Platform (Cloud Run, GCE, GKE, etc.) every compute instance
/// has an attached service account whose Bearer token is available at a local
/// HTTP endpoint — no credential files or JWT signing required.
///
/// The metadata server is only reachable from within GCP. For local development,
/// use ``ServiceAccountTokenProvider`` with a downloaded service-account JSON key.
actor ADCTokenProvider: TokenProviding {

    private let httpClient:  HTTPClient
    private let decoder:     any FCMJSONDecoder
    private let tokenURL:    String
    private var cachedToken: String?
    private var tokenExpiry: Date = .distantPast

    /// Creates an ADC token provider.
    ///
    /// - Parameters:
    ///   - httpClient:          `HTTPClient` used to reach the metadata server.
    ///   - decoder:             Decoder for the token response.
    ///   - serviceAccountEmail: The service account to impersonate. Pass `nil` to use
    ///                          the instance's **default** service account (recommended).
    init(
        httpClient:          HTTPClient,
        decoder:             any FCMJSONDecoder,
        serviceAccountEmail: String? = nil
    ) {
        self.httpClient = httpClient
        self.decoder    = decoder

        let account = serviceAccountEmail ?? "default"
        self.tokenURL = "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/\(account)/token"
    }

    func validToken() async throws -> String {
        if let token = cachedToken, tokenExpiry > Date(timeIntervalSinceNow: 60) {
            return token
        }
        return try await refreshToken()
    }

    // MARK: - Private

    private func refreshToken() async throws -> String {
        var req = HTTPClientRequest(url: tokenURL)
        // Required header — requests without it are rejected by the metadata server.
        req.headers.add(name: "Metadata-Flavor", value: "Google")

        let response = try await httpClient.execute(req, timeout: .seconds(10))
        let buffer   = try await response.body.collect(upTo: 65_536)

        guard response.status.code == 200 else {
            var copy = buffer
            let body = copy.readString(length: buffer.readableBytes) ?? ""
            throw FCMError.tokenGenerationFailed(
                "GCP metadata server HTTP \(response.status.code): \(body). " +
                "Ensure the instance's service account has the " +
                "Firebase Cloud Messaging API User role."
            )
        }

        do {
            let token   = try decoder.decode(OAuthToken.self, from: buffer)
            cachedToken = token.accessToken
            tokenExpiry = Date(timeIntervalSinceNow: TimeInterval(token.expiresIn))
            return token.accessToken
        } catch {
            throw FCMError.decodingFailed("ADC token: \(error)")
        }
    }
}
