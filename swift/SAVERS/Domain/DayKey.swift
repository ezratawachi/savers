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

    #if DEBUG
    /// Days a scenario moves "today" by.
    nonisolated(unsafe) static var shift = 0
    static var today: String { of(.now.addingTimeInterval(Double(shift) * 86400)) }
    #else
    static var today: String { of(.now) }
    #endif

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

    /// Spanish keeps the app's own formats ("Martes 29 sept", no commas); other languages, the iPhone's.
    private static func formatter(_ spanish: String, _ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = AppLanguage.locale
        f.calendar = calendar
        if AppLanguage.isSpanish { f.dateFormat = spanish } else { f.setLocalizedDateFormatFromTemplate(template) }
        return f
    }

    /// "Martes 29 sept", "Tuesday, Sep 29"
    static func head(_ key: String) -> String {
        formatter("EEEE d MMM", "EEEEMMMd").string(from: date(key)).replacingOccurrences(of: ".", with: "").capitalizedFirst
    }

    /// "Martes 29 de septiembre", "Tuesday, September 29"
    static func long(_ key: String) -> String {
        formatter("EEEE d 'de' MMMM", "EEEEMMMMd").string(from: date(key)).capitalizedFirst
    }

    /// "Mar 29 sept", "Tue, Sep 29"
    static func short(_ key: String) -> String {
        formatter("EEE d MMM", "EEEMMMd").string(from: date(key)).replacingOccurrences(of: ".", with: "").capitalizedFirst
    }

    /// "Septiembre"
    static func monthOnly(_ month: MonthIndex) -> String {
        formatter("LLLL", "LLLL").string(from: date(month.first)).capitalizedFirst
    }

    /// "Septiembre de 2026", "September 2026"
    static func monthName(_ month: MonthIndex) -> String {
        formatter("LLLL 'de' y", "LLLLy").string(from: date(month.first)).capitalizedFirst
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
