import Foundation

/// JSON in a chosen key order, on one line where it fits, so the configuration reads well inside a chat.
indirect enum OrderedJSON {
    case value(JSONValue)
    case object([(String, OrderedJSON)])
    case array([OrderedJSON])

    static func string(_ s: String) -> Self { .value(.string(s)) }
    static func number(_ n: Int) -> Self { .value(.number(Double(n))) }

    func rendered(indent: Int = 0) -> String {
        let flat = inline
        if flat.count + indent <= 96 || isScalar { return flat }
        let pad = String(repeating: " ", count: indent + 2)
        let end = String(repeating: " ", count: indent)
        switch self {
        case .value: return flat
        case .object(let pairs):
            let lines = pairs.map { pad + Self.encode(.string($0.0)) + ": " + $0.1.rendered(indent: indent + 2) }
            return "{\n" + lines.joined(separator: ",\n") + "\n" + end + "}"
        case .array(let items):
            let lines = items.map { pad + $0.rendered(indent: indent + 2) }
            return "[\n" + lines.joined(separator: ",\n") + "\n" + end + "]"
        }
    }

    private var isScalar: Bool { if case .value = self { true } else { false } }

    private var inline: String {
        switch self {
        case .value(let v): Self.encode(v)
        case .object(let pairs): "{" + pairs.map { Self.encode(.string($0.0)) + ": " + $0.1.inline }.joined(separator: ", ") + "}"
        case .array(let items): "[" + items.map(\.inline).joined(separator: ", ") + "]"
        }
    }

    private static func encode(_ v: JSONValue) -> String {
        (try? Persistence.encoder.encode(v)).flatMap { String(data: $0, encoding: .utf8) } ?? "null"
    }
}
