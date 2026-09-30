import SwiftUI

/// "Buenos días, Ezra" · "Martes 29 sept" · the kind of day.
struct TodayHeader: View {
    let ds: String
    let name: String
    let type: DayType
    let status: String?
    let onChip: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                TimelineView(.everyMinute) { context in
                    HStack(spacing: 6) {
                        Text(greeting(at: context.date))
                            .foregroundStyle(.muted)
                        if let status {
                            Text(status).foregroundStyle(.warn)
                        }
                    }
                    .font(.reading(17))
                }
                Text(DayKey.head(ds))
                    .font(.display(32, relativeTo: .largeTitle, weight: .heavy))
                    .foregroundStyle(.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 0)
            DayChip(type: type, action: onChip)
                .padding(.bottom, 6)
        }
    }

    private func greeting(at date: Date) -> String {
        let h = DayKey.calendar.component(.hour, from: date)
        let hello = h < 12 ? "Buenos días" : h < 19 ? "Buenas tardes" : "Buenas noches"
        return name.isEmpty ? hello : "\(hello), \(name)"
    }
}
