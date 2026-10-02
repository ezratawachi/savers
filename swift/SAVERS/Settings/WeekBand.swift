import SwiftUI

/// The top of Ajustes: your week on the night. Each day with its sun if it has SAVERS, the hour you get up,
/// and gym marked; a day off and Shabbat are just the horizon. The whole band opens Horario.
struct WeekBand: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let r = store.routine
        let todayW = DayKey.weekday(store.today)
        let savers = (0...6).filter { r.weekType($0).hasSavers }
        let gym = r.days(of: .gym).count
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Tu semana")
                        .font(.display(44, relativeTo: .largeTitle, weight: .heavy))
                        .tracking(-1)
                        .foregroundStyle(.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.muted)
                }
                Text(summary(savers.count, gym: gym))
                    .font(.reading(16, relativeTo: .subheadline))
                    .foregroundStyle(.muted)
            }
            HStack(alignment: .top, spacing: 4) {
                ForEach(0..<7, id: \.self) { w in
                    day(w, r, isToday: w == todayW)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tu semana: \(summary(savers.count, gym: gym))")
        .accessibilityHint("Abre tu horario")
        .accessibilityAddTraits(.isButton)
    }

    private func day(_ w: Int, _ r: Routine, isToday: Bool) -> some View {
        let type = r.weekType(w)
        return VStack(spacing: 6) {
            Text(Weekday.letters[w])
                .font(.reading(13, relativeTo: .caption).bold())
                .foregroundStyle(isToday ? Color.sky : Color.muted)
            DaySun(rise: type.hasSavers ? 1 : 0, diameter: 26)
                .padding(.horizontal, 2)
            VStack(spacing: 1) {
                switch type {
                case .normal, .gym:
                    Text(wakeTime(w, type, r))
                        .font(.reading(14, relativeTo: .footnote).bold())
                        .monospacedDigit()
                        .foregroundStyle(.ink)
                    Text("Gym")
                        .font(.reading(11, relativeTo: .caption2))
                        .foregroundStyle(.muted)
                        .opacity(type == .gym ? 1 : 0)
                case .shabbat:
                    Text("Shabbat")
                        .font(.reading(11, relativeTo: .caption2))
                        .foregroundStyle(.muted)
                default:
                    Text("Libre")
                        .font(.reading(11, relativeTo: .caption2))
                        .foregroundStyle(.muted)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    /// When you get up that weekday: its kind's first step.
    private func wakeTime(_ w: Int, _ type: DayType, _ r: Routine) -> String {
        guard let first = r.settings.schedule?.type(type)?[.steps].first else { return "—" }
        let t = r.usualTime(first, weekday: w)
        return t.isEmpty ? "—" : t
    }

    private func summary(_ savers: Int, gym: Int) -> String {
        let days = "\(savers) \(savers == 1 ? "día" : "días") de SAVERS"
        return gym > 0 ? "\(days) · \(gym) de gym" : days
    }
}
