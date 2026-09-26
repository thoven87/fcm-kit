import Foundation
import JWTKit
import AsyncHTTPClient
import NIOCore

/// OAuth 2.0 token provider that signs a JWT with a Firebase service-account
/// RSA key and exchanges it for a Bearer token at `oauth2.googleapis.com`.
///
/// This is the correct provider when running outside GCP (local development,
/// non-Google cloud, on-premises, etc.).
actor ServiceAccountTokenProvider: TokenProviding {

    private let credentials: ServiceAccount
    private let httpClient:  HTTPClient
    private let decoder:     any FCMJSONDecoder
    private var cachedToken: String?
    private var tokenExpiry: Date = .distantPast

    /// - Throws: ``FCMError/invalidCredentials(_:)`` if the private-key PEM is malformed.
    init(
        credentials: ServiceAccount,
        httpClient:  HTTPClient,
        decoder:     any FCMJSONDecoder
    ) throws {
        // Validate the key eagerly so failures surface at init time.
        _ = try Insecure.RSA.PrivateKey(pem: credentials.privateKey)
        self.credentials = credentials
        self.httpClient  = httpClient
        self.decoder     = decoder
    }

    func validToken() async throws -> String {
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
        let rsaKey = try Insecure.RSA.PrivateKey(pem: credentials.privateKey)
        let keys   = JWTKeyCollection()
        await keys.add(
            rsa:             rsaKey,
            digestAlgorithm: .sha256,
            kid:             JWKIdentifier(string: credentials.privateKeyID)
        )
        return try await keys.sign(payload, kid: JWKIdentifier(string: credentials.privateKeyID))
    }

    private func exchangeJWT(_ jwt: String) async throws -> OAuthToken {
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

// MARK: - Private JWT payload

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
