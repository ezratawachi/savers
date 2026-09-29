import UIKit
import Capacitor
import AuthenticationServices
import CryptoKit

// Google sign-in for the web inside the app. Google blocks its login page inside a web view, and SAVERS'
// popup ends up in Safari, where the result never comes back. So the app signs in with the system login sheet
// (the same Safari cookies, so the account is usually already there) and hands the Google tokens to the web,
// which signs into Firebase with them (signInWithCredential).
// The client is the iOS OAuth client of the Firebase project savers-ezra, made for com.ezratawachi.savers.
private let googleClientId = "22715050591-3jb2l7vk50k1an2vg1a46snc0f4jdo02.apps.googleusercontent.com"
private let googleScheme = "com.googleusercontent.apps.22715050591-3jb2l7vk50k1an2vg1a46snc0f4jdo02"

// Registers the app's own plugins; Main.storyboard points at this class.
class MainViewController: CAPBridgeViewController {
    override open func capacitorDidLoad() {
        bridge?.registerPluginInstance(GoogleLoginPlugin())
    }
}

@objc(GoogleLoginPlugin)
public class GoogleLoginPlugin: CAPPlugin, CAPBridgedPlugin, ASWebAuthenticationPresentationContextProviding {
    public let identifier = "GoogleLoginPlugin"
    public let jsName = "GoogleLogin"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "signIn", returnType: CAPPluginReturnPromise)
    ]
    private var session: ASWebAuthenticationSession?

    @objc func signIn(_ call: CAPPluginCall) {
        let redirect = googleScheme + ":/oauth2redirect"
        let verifier = randomString(64)
        let challenge = base64url(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = randomString(24)
        var url = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        url.queryItems = [
            URLQueryItem(name: "client_id", value: googleClientId),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "prompt", value: "select_account")
        ]
        DispatchQueue.main.async {
            let session = ASWebAuthenticationSession(url: url.url!, callbackURLScheme: googleScheme) { callback, error in
                self.session = nil
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    call.reject("Cancelado", "cancelled")
                    return
                }
                let items = callback.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
                guard items.first(where: { $0.name == "state" })?.value == state,
                      let code = items.first(where: { $0.name == "code" })?.value else {
                    call.reject("Google no devolvió el código", "failed")
                    return
                }
                self.exchange(code: code, verifier: verifier, redirect: redirect, call: call)
            }
            session.presentationContextProvider = self
            self.session = session
            if !session.start() { call.reject("No se pudo abrir Google", "failed") }
        }
    }

    // PKCE code -> tokens. An iOS client has no secret; the verifier proves the request is ours.
    private func exchange(code: String, verifier: String, redirect: String, call: CAPPluginCall) {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: googleClientId),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code_verifier", value: verifier)
        ]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let idToken = json["id_token"] as? String else {
                call.reject("No se pudo terminar el inicio con Google", error == nil ? "failed" : "network")
                return
            }
            call.resolve(["idToken": idToken, "accessToken": json["access_token"] as? String ?? ""])
        }.resume()
    }

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return bridge?.viewController?.view.window ?? ASPresentationAnchor()
    }

    private func randomString(_ count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return base64url(Data(bytes))
    }

    private func base64url(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
