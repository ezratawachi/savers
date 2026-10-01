import SwiftUI

/// An hour of the schedule ("5:20", "10:10 pm") on the iPhone's own time wheel.
struct TimeWheel: View {
    let label: String
    let time: String
    let onChange: (String) -> Void

    var body: some View {
        DatePicker(label, selection: binding, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
    }

    private var binding: Binding<Date> {
        Binding {
            let m = TimeText.minutes(time) ?? 0
            return DayKey.calendar.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let p = DayKey.calendar.dateComponents([.hour, .minute], from: date)
            onChange(TimeText.label((p.hour ?? 0) * 60 + (p.minute ?? 0)))
        }
    }
}

/// Minutes on a wheel. Silencio's and Lectura's by default: 1…60, then quarter hours up to two hours.
struct MinutesWheel: View {
    let label: String
    let minutes: Int
    var choices = Self.letterChoices
    let onChange: (Int) -> Void

    static let letterChoices = Routine.minuteChoices

    var body: some View {
        let options = choices.contains(minutes) ? choices : (choices + [minutes]).sorted()
        Picker(label, selection: Binding { minutes } set: { onChange($0) }) {
            ForEach(options, id: \.self) { Text("\($0) min").tag($0) }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
    }
}
