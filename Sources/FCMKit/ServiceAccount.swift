import Foundation

/// A decoded Firebase service-account JSON credential.
///
/// Obtain the JSON from the Firebase console:
/// **Project Settings → Service Accounts → Generate new private key**.
///
/// Load it in whichever way suits your deployment:
///
/// ```swift
/// // From a file path
/// let account = try ServiceAccount.load(contentsOfFile: "/run/secrets/sa.json")
///
/// // From an environment variable or secret manager
/// let json    = ProcessInfo.processInfo.environment["FIREBASE_SA_JSON"]!
/// let account = try ServiceAccount.load(fromJSON: json)
///
/// // From raw Data
/// let account = try ServiceAccount.load(from: jsonData)
/// ```
public struct ServiceAccount: Decodable, Sendable {

    public let projectID:    String
    public let privateKeyID: String
    /// PEM-encoded RSA private key (PKCS #8).
    public let privateKey:   String
    public let clientEmail:  String
    /// OAuth 2.0 token endpoint — typically `https://oauth2.googleapis.com/token`.
    public let tokenURI:     String

    // MARK: - Factory helpers

    /// Decode a ``ServiceAccount`` from raw JSON `Data`.
    public static func load(from data: Data) throws -> ServiceAccount {
        do {
            return try JSONDecoder().decode(ServiceAccount.self, from: data)
        } catch {
            throw FCMError.invalidCredentials("Failed to decode service account: \(error)")
        }
    }

    /// Decode a ``ServiceAccount`` from a JSON `String`.
    ///
    /// Useful when credentials arrive via an environment variable or a secret-management service:
    ///
    /// ```swift
    /// let json    = ProcessInfo.processInfo.environment["FIREBASE_SA_JSON"]!
    /// let account = try ServiceAccount.load(fromJSON: json)
    /// ```
    public static func load(fromJSON json: String) throws -> ServiceAccount {
        guard let data = json.data(using: .utf8) else {
            throw FCMError.invalidCredentials("Service account JSON string is not valid UTF-8")
        }
        return try load(from: data)
    }

    /// Decode a ``ServiceAccount`` from a JSON file on disk.
    public static func load(contentsOfFile path: String) throws -> ServiceAccount {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try load(from: data)
    }

    // MARK: - Decodable

    private enum CodingKeys: String, CodingKey {
        case projectID    = "project_id"
        case privateKeyID = "private_key_id"
        case privateKey   = "private_key"
        case clientEmail  = "client_email"
        case tokenURI     = "token_uri"
    }
}
