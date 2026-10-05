/// The week as it was until a date: what each weekday was before you changed it, so the days that passed stay
/// the kind they were.
struct PastWeek: Codable, Equatable, Sendable {
    /// The last date it was in force, "AAAA-MM-DD".
    var until: String
    /// "0" (Sunday) … "6" (Saturday) → a kind's id.
    var week: [String: String]
}
