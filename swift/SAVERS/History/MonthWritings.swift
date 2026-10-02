import SwiftUI

/// "What you wrote": the month's days with something written, newest first, read in full. Days with
/// only their letters are in the suns above; tapping a day here opens it too.
struct MonthWritings: View {
    @Environment(AppStore.self) private var store
    let month: MonthIndex
    let onOpen: (String) -> Void

    var body: some View {
        let list = month.dates.reversed().filter { ds in
            WritingField.allCases.contains { !(store.days[ds]?[$0].isEmpty ?? true) }
        }
        if list.isEmpty {
            Group {
                if month.first > store.today {
                    Text("This month hasn't come yet. Tap a day to plan its hours.")
                } else {
                    Text("Your words from \(Letter.escritura.name) will show up here.")
                }
            }
            .font(.reading())
            .foregroundStyle(.muted)
        } else {
            VStack(spacing: 10) {
                ForEach(list, id: \.self) { ds in
                    Button { onOpen(ds) } label: { entry(ds, store.routine.day(ds)) }
                        .buttonStyle(PressScale(scale: 0.98))
                        .accessibilityLabel("What you wrote on \(DayKey.long(ds).inSentence)")
                        .accessibilityHint("Opens that day")
                }
            }
        }
    }

    private func entry(_ ds: String, _ d: Day) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(DayKey.head(ds))
                    .font(.reading(13, relativeTo: .footnote))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(.muted)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.muted)
                    .opacity(0.6)
            }
            ForEach(WritingField.allCases) { f in
                if !d[f].isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(f.label)
                            .font(.reading(14, relativeTo: .caption).bold())
                            .foregroundStyle(.muted)
                        Text(d[f])
                            .font(.reading(18, relativeTo: .body))
                            .lineSpacing(3)
                            .foregroundStyle(.ink)
                    }
                }
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CardLayout.inset)
        .background {
            RoundedRectangle(cornerRadius: CardLayout.radius)
                .fill(Color.surface)
                .stroke(Color.line, lineWidth: 1)
        }
        .contentShape(.rect(cornerRadius: CardLayout.radius))
    }
}
