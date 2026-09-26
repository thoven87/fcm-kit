import Foundation
import JWTKit
import AsyncHTTPClient
import NIOCore

/// OAuth 2.0 token manager.
///
/// - Validates the RSA private key once at initialisation.
/// - Caches the access token and refreshes it automatically 60 seconds before expiry.
actor TokenProvider {

    // MARK: - State

    private let credentials: ServiceAccount
    private let httpClient:  HTTPClient
    private let decoder:     any FCMJSONDecoder
    private var cachedToken: String?
    private var tokenExpiry: Date = .distantPast

    // MARK: - Init

    /// Throws ``FCMError/invalidCredentials(_:)`` if the private-key PEM is malformed.
    init(
        credentials: ServiceAccount,
        httpClient:  HTTPClient,
        decoder:     any FCMJSONDecoder
    ) throws {
        // Validate key format eagerly so failures surface at initialisation,
        // not buried inside the first send call.
        _ = try Insecure.RSA.PrivateKey(pem: credentials.privateKey)
        self.credentials = credentials
        self.httpClient  = httpClient
        self.decoder     = decoder
    }

    // MARK: - Interface

    /// Returns a valid Bearer token, refreshing from Google if needed.
    func validToken() async throws -> String {
        // Refresh 60 s before actual expiry to avoid races on slow connections.
        if let token = cachedToken, tokenExpiry > Date(timeIntervalSinceNow: 60) {
            return token
        }
        return try await refreshToken()
    }

    // MARK: - Private

    private func refreshToken() async throws -> String {
        let jwt        = try await signJWT()
        let oauthToken = try await exchangeJWT(jwt)
        cachedToken    = oauthToken.accessToken
        tokenExpiry    = Date(timeIntervalSinceNow: TimeInterval(oauthToken.expiresIn))
        return oauthToken.accessToken
    }

    private func signJWT() async throws -> String {
        let now = Date()

        let payload = GoogleJWTPayload(
            iss:   IssuerClaim(value: credentials.clientEmail),
            scope: "https://www.googleapis.com/auth/firebase.messaging",
            aud:   AudienceClaim(value: [credentials.tokenURI]),
            iat:   IssuedAtClaim(value: now),
            exp:   ExpirationClaim(value: now.addingTimeInterval(3_600))
        )

        // Re-parse per refresh — negligible cost (~µs) vs the network round-trip.
        let rsaKey = try Insecure.RSA.PrivateKey(pem: credentials.privateKey)
        let keys   = JWTKeyCollection()
        await keys.add(
            rsa:             rsaKey,
            digestAlgorithm: .sha256,
            kid:             JWKIdentifier(string: credentials.privateKeyID)
        )
        return try await keys.sign(
            payload,
            kid: JWKIdentifier(string: credentials.privateKeyID)
        )
    }

    private func exchangeJWT(_ jwt: String) async throws -> OAuthToken {
        // RFC 7523 — JWT Bearer grant
        let assertion   = jwt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? jwt
        let formPayload = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=\(assertion)"

        var req = HTTPClientRequest(url: credentials.tokenURI)
        req.method = .POST
        req.headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
        req.body = .bytes(Array(formPayload.utf8))

        let response = try await httpClient.execute(req, timeout: .seconds(30))
        let buffer   = try await response.body.collect(upTo: 65_536)

        guard response.status.code == 200 else {
            var copy = buffer
            let body = copy.readString(length: buffer.readableBytes) ?? ""
            throw FCMError.tokenGenerationFailed("HTTP \(response.status.code): \(body)")
        }

        do {
            return try decoder.decode(OAuthToken.self, from: buffer)
        } catch {
            throw FCMError.decodingFailed("OAuth token: \(error)")
        }
    }
}

// MARK: - Private types

private struct GoogleJWTPayload: JWTPayload {
    var iss:   IssuerClaim
    var scope: String
    var aud:   AudienceClaim
    var iat:   IssuedAtClaim
    var exp:   ExpirationClaim

    func verify(using _: some JWTAlgorithm) throws {
        try exp.verifyNotExpired()
    }
}

private struct OAuthToken: Decodable {
    let accessToken: String
    let expiresIn:   Int
    let tokenType:   String

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn   = "expires_in"
        case tokenType   = "token_type"
    }
}
