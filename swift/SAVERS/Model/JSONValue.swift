import Foundation

/// Any JSON value. Keeps fields this app doesn't use (or legacy ones) exactly as the web wrote them,
/// because the web and this app share the same files and the same Firestore.
enum JSONValue: Codable, Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n):
            if n.rounded() == n, abs(n) < 1e15 { try c.encode(Int(n)) } else { try c.encode(n) }
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    /// The web's `Number(v)`: numbers, and strings that hold one.
    var number: Double? {
        switch self {
        case .number(let n): n
        case .string(let s): Double(s.trimmingCharacters(in: .whitespaces))
        default: nil
        }
    }

    /// The web's `String(v)` for the values it stores as text.
    var text: String? {
        switch self {
        case .string(let s): s
        case .number: number.map { $0.rounded() == $0 ? String(Int($0)) : String($0) }
        default: nil
        }
    }
}

/// A coding key for any name, to read and write the fields a type doesn't declare.
struct AnyKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

extension KeyedDecodingContainer where K == AnyKey {
    /// Every field not in `known`, kept as-is.
    func extras(excluding known: Set<String>) -> [String: JSONValue] {
        var out: [String: JSONValue] = [:]
        for key in allKeys where !known.contains(key.stringValue) {
            if let v = try? decode(JSONValue.self, forKey: key) { out[key.stringValue] = v }
        }
        return out
    }

    func lenient<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        try? decodeIfPresent(T.self, forKey: AnyKey(name))
    }
}

extension KeyedEncodingContainer where K == AnyKey {
    mutating func encodeExtras(_ extras: [String: JSONValue]) throws {
        for (k, v) in extras { try encode(v, forKey: AnyKey(k)) }
    }
}
