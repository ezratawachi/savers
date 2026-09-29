import Foundation

enum CloudError: Error, Equatable {
    case cancelled
    case offline
    /// The sign-in ran out (401): get a new token and try again.
    case unauthorized
    /// The rules don't let this account in (403).
    case denied
    /// The session can't be renewed anymore: sign in again.
    case signedOut
    case notFound
    case failed
}

/// JSON over HTTPS, answers read as `JSONValue`.
enum Net {
    static func get(_ url: String, token: String? = nil) async throws -> JSONValue {
        try await send(request(url, method: "GET", token: token))
    }

    static func post(_ url: String, _ body: JSONValue, token: String? = nil) async throws -> JSONValue {
        var r = request(url, method: "POST", token: token)
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONEncoder().encode(body)
        return try await send(r)
    }

    static func form(_ url: String, _ form: URLComponents) async throws -> JSONValue {
        var r = request(url, method: "POST", token: nil)
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        r.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        return try await send(r)
    }

    private static func request(_ url: String, method: String, token: String?) -> URLRequest {
        var r = URLRequest(url: URL(string: url)!, timeoutInterval: 20)
        r.httpMethod = method
        if let token { r.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        return r
    }

    private static func send(_ r: URLRequest) async throws -> JSONValue {
        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: r)
        } catch let e as URLError where e.code != .cancelled {
            throw CloudError.offline
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300: return (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .null
        case 401: throw CloudError.unauthorized
        case 403: throw CloudError.denied
        case 404: throw CloudError.notFound
        case 400 where r.url?.host() == "securetoken.googleapis.com": throw CloudError.signedOut
        default: throw CloudError.failed
        }
    }
}

extension JSONValue {
    subscript(key: String) -> JSONValue? {
        if case .object(let o) = self { return o[key] }
        return nil
    }

    var string: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var array: [JSONValue] {
        if case .array(let a) = self { return a }
        return []
    }
}
