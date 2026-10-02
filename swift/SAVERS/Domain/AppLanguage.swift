import Foundation

/// The language the app speaks: Spanish or English, whichever the iPhone prefers (English otherwise).
enum AppLanguage {
    /// "en" or "es".
    static let code = Bundle.main.preferredLocalizations.first ?? "en"
    static var isSpanish: Bool { code == "es" }

    /// For dates and weekdays: the iPhone's own region when it speaks this language ("es_MX"), or else the
    /// plain language, so an English app on a French iPhone doesn't name its days in French.
    static let locale: Locale = Locale.current.language.languageCode?.identifier == code ? .current : Locale(identifier: code)

    /// "a, b y c", "a, b and c"
    static func list(_ items: [String]) -> String {
        let f = ListFormatter()
        f.locale = locale
        return f.string(from: items) ?? items.joined(separator: ", ")
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }

    /// A date or a name in the middle of a sentence: Spanish lowers it ("el martes"), English keeps it ("on Tuesday").
    var inSentence: String { AppLanguage.isSpanish ? lowercased() : self }
}
