// MARK: - TokenProviding

/// Internal abstraction over OAuth 2.0 token acquisition strategies.
///
/// Two concrete implementations:
/// - ``ServiceAccountTokenProvider`` — signs a JWT with a service-account RSA key
///   and exchanges it for a Bearer token at `oauth2.googleapis.com`.
/// - ``ADCTokenProvider`` — fetches a Bearer token from the GCP metadata server
///   (available on Cloud Run, GCE, GKE, etc.).
protocol TokenProviding: Sendable {
    /// Returns a valid Bearer token, refreshing it from the upstream source when needed.
    func validToken() async throws -> String
}

// MARK: - OAuthToken (shared by both providers)

/// Google OAuth 2.0 token response.
struct OAuthToken: Decodable {
    let accessToken: String
    let expiresIn:   Int
    let tokenType:   String

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn   = "expires_in"
        case tokenType   = "token_type"
    }
}
