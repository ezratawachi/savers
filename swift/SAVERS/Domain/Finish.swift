/// How far the day has gone.
enum Finish: Int, Comparable {
    case none, morning, day

    static func < (a: Finish, b: Finish) -> Bool { a.rawValue < b.rawValue }
}
