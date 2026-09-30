import Foundation

/// Dates as the data writes them: "AAAA-MM-DD", in the phone's own time zone.
enum DayKey {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    static func of(_ date: Date) -> String {
        let p = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0)
    }

    static var today: String { of(.now) }

    static func date(_ key: String) -> Date {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return .now }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) ?? .now
    }

    static func isValid(_ key: String) -> Bool { key.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil }

    /// 0 = Sunday … 6 = Saturday
    static func weekday(_ key: String) -> Int { calendar.component(.weekday, from: date(key)) - 1 }

    static func adding(_ days: Int, to key: String) -> String {
        of(calendar.date(byAdding: .day, value: days, to: date(key)) ?? .now)
    }

    /// "AAAA-MM"
    static func month(_ key: String) -> String { String(key.prefix(7)) }

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es")
        f.calendar = calendar
        f.dateFormat = format
        return f
    }

    /// "Martes 29 sept"
    static func head(_ key: String) -> String {
        let s = formatter("EEEE d MMM").string(from: date(key)).replacingOccurrences(of: ".", with: "")
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    /// "Martes 29 de septiembre"
    static func long(_ key: String) -> String {
        formatter("EEEE d 'de' MMMM").string(from: date(key)).capitalizedFirst
    }

    /// "Mar 29 sept"
    static func short(_ key: String) -> String {
        formatter("EEE d MMM").string(from: date(key)).replacingOccurrences(of: ".", with: "").capitalizedFirst
    }

    /// "Septiembre de 2026"
    static func monthName(_ month: MonthIndex) -> String {
        formatter("LLLL 'de' y").string(from: date(month.first)).capitalizedFirst
    }
}

/// A month as one number (year × 12 + month − 1), so months line up in a pager.
struct MonthIndex: Hashable, Comparable, Strideable {
    let value: Int

    init(_ value: Int) { self.value = value }
    init(of key: String) {
        let p = key.split(separator: "-").compactMap { Int($0) }
        value = p.count >= 2 ? p[0] * 12 + p[1] - 1 : 0
    }

    var year: Int { value / 12 }
    var month: Int { value % 12 + 1 }
    /// "AAAA-MM-01"
    var first: String { String(format: "%04d-%02d-01", year, month) }
    var dayCount: Int { DayKey.calendar.range(of: .day, in: .month, for: DayKey.date(first))?.count ?? 30 }
    /// Every date of the month, "AAAA-MM-DD".
    var dates: [String] { (1...dayCount).map { String(format: "%04d-%02d-%02d", year, month, $0) } }

    static func < (a: Self, b: Self) -> Bool { a.value < b.value }
    func distance(to other: Self) -> Int { other.value - value }
    func advanced(by n: Int) -> Self { Self(value + n) }
}
