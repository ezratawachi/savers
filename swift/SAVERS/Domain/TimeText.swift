import Foundation

/// Hours as the schedule writes them: "5:20" (morning, no am), "10:10 pm", "12:10 am".
enum TimeText {
    /// → minutes of the day, or nil.
    static func minutes(_ s: String?) -> Int? {
        guard let s else { return nil }
        let pattern = /^\s*(\d{1,2}):(\d{2})\s*([aApP])?\.?\s*[mM]?\.?\s*$/
        guard let m = s.wholeMatch(of: pattern), var h = Int(m.1), let mm = Int(m.2) else { return nil }
        h %= 24
        let ap = m.3.map { $0.lowercased() } ?? ""
        if ap == "p" && h < 12 { h += 12 }
        if ap == "a" && h == 12 { h = 0 }
        return h * 60 + mm
    }

    /// Minutes of the day → "5:20", "12:10 am", "10:10 pm".
    static func label(_ minutes: Int) -> String {
        let h = (minutes / 60) % 24
        let mm = String(format: "%02d", minutes % 60)
        if h < 12 { return h == 0 ? "12:\(mm) am" : "\(h):\(mm)" }
        return "\(h == 12 ? 12 : h - 12):\(mm) pm"
    }

    static func same(_ a: String?, _ b: String?) -> Bool {
        guard let x = minutes(a) else { return false }
        return x == minutes(b)
    }

    /// "5:15–6:00" → 45
    static func span(_ range: String?) -> Int? {
        guard let range, let m = range.firstMatch(of: /(\d{1,2}):(\d{2})\s*[–-]\s*(\d{1,2}):(\d{2})/),
              let a = Int(m.1), let b = Int(m.2), let c = Int(m.3), let d = Int(m.4) else { return nil }
        let mins = (c * 60 + d) - (a * 60 + b)
        return mins > 0 ? mins : nil
    }
}
