import Foundation

/// What a date is. Normal and gym have the sunrise with their own hours; off (Rest) has none; Saturday is Shabbat.
enum DayType: String, Sendable {
    case normal, gym, off, shabbat

    /// The three a weekday or a date can be set to.
    static let choosable: [DayType] = [.normal, .gym, .off]

    /// Weekday (0 = Sunday … 5 = Friday) when the schedule doesn't say.
    static let defaultWeek: [Int: DayType] = [0: .off, 1: .normal, 2: .normal, 3: .gym, 4: .normal, 5: .gym]

    var hasSavers: Bool { self == .normal || self == .gym }

    var name: String {
        switch self {
        case .normal: String(localized: "Normal")
        case .gym: String(localized: "Gym")
        case .off: String(localized: "Rest")
        case .shabbat: "Shabbat"
        }
    }

    var chipName: String {
        switch self {
        case .normal: String(localized: "Normal day")
        case .gym: String(localized: "Gym day")
        case .off: String(localized: "Rest day")
        case .shabbat: "Shabbat"
        }
    }
}
