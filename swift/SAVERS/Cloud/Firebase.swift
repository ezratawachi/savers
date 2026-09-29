import Foundation

/// Firebase Auth and Firestore over their REST APIs, the same project and paths as the web.
/// The API key is public by design; the Firestore rules let only the owner's Google account in.
enum Firebase {
    private static let apiKey = "AIzaSyDoPNQn11bcA1mamy7TeedgaYBb91VvJPk"
    private static let root = "projects/savers-ezra/databases/(default)/documents"
    private static let base = "https://firestore.googleapis.com/v1/"

    struct Session {
        var uid: String
        var idToken: String
        var refreshToken: String
        var expires: Date
        var email: String?
    }

    // MARK: Auth

    /// Google's id token -> a Firebase session (what the web's `signInWithCredential` does).
    static func signIn(googleIdToken: String) async throws -> Session {
        let body: JSONValue = .object([
            "postBody": .string("id_token=\(googleIdToken)&providerId=google.com"),
            "requestUri": .string("http://localhost"),
            "returnSecureToken": .bool(true)
        ])
        let r = try await Net.post("https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=\(apiKey)", body)
        guard let uid = r["localId"]?.string, let id = r["idToken"]?.string, let refresh = r["refreshToken"]?.string else { throw CloudError.failed }
        return Session(uid: uid, idToken: id, refreshToken: refresh, expires: expiry(r["expiresIn"]), email: r["email"]?.string)
    }

    /// A new id token (they last an hour) from the saved refresh token.
    static func refresh(_ refreshToken: String) async throws -> Session {
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken)
        ]
        let r = try await Net.form("https://securetoken.googleapis.com/v1/token?key=\(apiKey)", form)
        guard let uid = r["user_id"]?.string, let id = r["id_token"]?.string else { throw CloudError.failed }
        return Session(uid: uid, idToken: id, refreshToken: r["refresh_token"]?.string ?? refreshToken, expires: expiry(r["expires_in"]))
    }

    private static func expiry(_ v: JSONValue?) -> Date {
        .now.addingTimeInterval((v?.number ?? 3600) - 120)
    }

    // MARK: Firestore

    /// `users/{uid}/meta/settings` as plain JSON, or nil if it isn't there.
    static func document(_ path: String, token: String) async throws -> [String: JSONValue]? {
        do {
            let doc = try await Net.get(base + root + "/" + path, token: token)
            return plainFields(doc["fields"])
        } catch CloudError.notFound {
            return nil
        }
    }

    /// The days written since `since` (their `syncedAt`), each with its date and `syncedAt`.
    static func days(uid: String, since: Date, token: String) async throws -> [(id: String, fields: [String: JSONValue], syncedAt: Date?)] {
        let query: JSONValue = .object(["structuredQuery": .object([
            "from": .array([.object(["collectionId": .string("days")])]),
            "where": .object(["fieldFilter": .object([
                "field": .object(["fieldPath": .string("syncedAt")]),
                "op": .string("GREATER_THAN"),
                "value": .object(["timestampValue": .string(since.iso)])
            ])])
        ])])
        let rows = try await Net.post(base + root + "/users/\(uid):runQuery", query, token: token)
        return rows.array.compactMap { row in
            guard let doc = row["document"], let name = doc["name"]?.string, let fields = plainFields(doc["fields"]) else { return nil }
            let at = doc["fields"]?["syncedAt"]?["timestampValue"]?.string.flatMap(parseTimestamp)
            return (String(name.split(separator: "/").last ?? ""), fields, at)
        }
    }

    /// Writes whole documents (like the web's `setDoc`), each with `syncedAt` set by the server. At most 500.
    static func write(_ docs: [(path: String, fields: [String: JSONValue])], token: String) async throws {
        guard !docs.isEmpty else { return }
        let writes: [JSONValue] = docs.map { doc in
            .object([
                "update": .object([
                    "name": .string(root + "/" + doc.path),
                    "fields": .object(doc.fields.mapValues(firestoreValue))
                ]),
                "updateTransforms": .array([.object([
                    "fieldPath": .string("syncedAt"),
                    "setToServerValue": .string("REQUEST_TIME")
                ])])
            ])
        }
        _ = try await Net.post(base + root + ":commit", .object(["writes": .array(writes)]), token: token)
    }

    // MARK: Values

    /// JSON -> Firestore's typed value. Whole numbers go as integers, like the web SDK does.
    static func firestoreValue(_ v: JSONValue) -> JSONValue {
        switch v {
        case .null: .object(["nullValue": .null])
        case .bool(let b): .object(["booleanValue": .bool(b)])
        case .number(let n):
            n.rounded() == n && abs(n) < 9e15 ? .object(["integerValue": .string(String(Int(n)))]) : .object(["doubleValue": .number(n)])
        case .string(let s): .object(["stringValue": .string(s)])
        case .array(let a): .object(["arrayValue": a.isEmpty ? .object([:]) : .object(["values": .array(a.map(firestoreValue))])])
        case .object(let o): .object(["mapValue": o.isEmpty ? .object([:]) : .object(["fields": .object(o.mapValues(firestoreValue))])])
        }
    }

    /// Firestore's typed value -> JSON. Timestamps come back as their text.
    static func plainValue(_ v: JSONValue) -> JSONValue {
        guard case .object(let o) = v, let (type, inner) = o.first else { return .null }
        switch type {
        case "booleanValue": return inner
        case "integerValue", "doubleValue": return inner.number.map(JSONValue.number) ?? .null
        case "stringValue", "timestampValue": return inner
        case "arrayValue": return .array((inner["values"]?.array ?? []).map(plainValue))
        case "mapValue": return .object(plainFields(inner["fields"]) ?? [:])
        default: return .null
        }
    }

    private static func plainFields(_ v: JSONValue?) -> [String: JSONValue]? {
        guard let v else { return [:] }
        guard case .object(let o) = v else { return nil }
        return o.mapValues(plainValue)
    }

    /// "2026-09-29T21:00:00.123456Z": any number of decimals.
    static func parseTimestamp(_ s: String) -> Date? {
        let parts = s.dropLast().split(separator: ".", maxSplits: 1)
        guard s.hasSuffix("Z"), let first = parts.first, let whole = try? Date(String(first) + "Z", strategy: .iso8601) else { return nil }
        let fraction = parts.count > 1 ? Double("0." + parts[1]) ?? 0 : 0
        return whole.addingTimeInterval(fraction)
    }
}
