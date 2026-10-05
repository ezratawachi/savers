import Foundation

/// A kind of day, as the schedule keeps it (`schedule.types[id]`): one with the sunrise and its hours, or one of
/// rest that only has a name. Two are the same kind when their ids are.
struct DayType: Hashable, Identifiable, Sendable {
    let id: String
    /// The name you gave it; nil keeps the app's own ("Normal", "Rest"), in the app's language.
    let ownName: String?
    let hasSunrise: Bool
    /// When it was made: the oldest comes first.
    let order: Int
    /// Removed from the list; still remembered for the days that were this kind.
    let deleted: Bool

    init(id: String, _ t: TypeSchedule) {
        self.id = id
        ownName = t.name.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
        hasSunrise = t.rest != true
        order = t.order ?? Int.max
        deleted = t.deleted == true
    }

    var name: String { ownName ?? (hasSunrise ? String(localized: "Normal") : String(localized: "Rest")) }

    static func == (a: DayType, b: DayType) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    /// The ids your days had before kinds were your own; the past still says them.
    static let normal = "normal", gym = "gym", rest = "off", shabbat = "shabbat"
}
