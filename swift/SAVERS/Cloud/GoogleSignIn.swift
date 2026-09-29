import SwiftUI
import AuthenticationServices
import CryptoKit
import Foundation

/// Google's sign-in with the system sheet (the same Safari cookies, so the account is usually already there).
/// PKCE, no SDK. The client is the iOS OAuth client of the Firebase project savers-ezra, made for this bundle id.
enum GoogleSignIn {
    private static let clientId = "22715050591-3jb2l7vk50k1an2vg1a46snc0f4jdo02.apps.googleusercontent.com"
    private static let scheme = "com.googleusercontent.apps.22715050591-3jb2l7vk50k1an2vg1a46snc0f4jdo02"
    private static var redirect: String { scheme + ":/oauth2redirect" }

    /// Google's id token for this account. Throws `CloudError.cancelled` if the sheet is closed.
    static func idToken(using session: WebAuthenticationSession) async throws -> String {
        let verifier = randomString(64)
        let challenge = base64url(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = randomString(24)
        var url = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        url.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "prompt", value: "select_account")
        ]
        let callback: URL
        do {
            callback = try await session.authenticate(using: url.url!, callbackURLScheme: scheme, preferredBrowserSession: .shared)
        } catch let e as ASWebAuthenticationSessionError where e.code == .canceledLogin {
            throw CloudError.cancelled
        }
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value else { throw CloudError.failed }
        return try await exchange(code: code, verifier: verifier)
    }

    /// Code -> tokens. An iOS client has no secret; the verifier proves the request is ours.
    private static func exchange(code: String, verifier: String) async throws -> String {
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code_verifier", value: verifier)
        ]
        let json = try await Net.form("https://oauth2.googleapis.com/token", form)
        guard let token = json["id_token"]?.string else { throw CloudError.failed }
        return token
    }

    private static func randomString(_ count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return base64url(Data(bytes))
    }

    private static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
