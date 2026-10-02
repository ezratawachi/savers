import Foundation

/// "Undo the AI's last changes": the settings and the dates it touched, just before and just after.
/// Kept on this iPhone until the next changes from an AI.
struct AIUndo: Codable {
    /// What the AI can change on a date.
    struct DateFields: Codable, Equatable {
        var type: String?
        var times: [String: String]?
        var mins: [String: JSONValue]?

        init(_ d: Day?) {
            type = d?.type
            times = d?.times
            mins = d?.mins
        }
    }

    var before: AppSettings
    var after: AppSettings
    var datesBefore: [String: DateFields]
    var datesAfter: [String: DateFields]

    /// Something changed after the AI's changes (by hand, or from the Mac): undoing loses it too.
    func changedSince(settings: AppSettings, days: [String: Day]) -> Bool {
        var now = settings
        now.aiNotes = after.aiNotes
        return now != after || datesAfter.contains { DateFields(days[$0.key]) != $0.value }
    }
}
