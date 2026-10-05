import SwiftUI

/// The top of Settings: your week on the night. Each day with its sun if it has a sunrise, the hour you get up,
/// and its kind when it isn't the usual one; a day of rest is just the horizon and its name. The whole band
/// opens Schedule.
struct WeekBand: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let r = store.routine
        let todayW = DayKey.weekday(store.today)
        let line = summary(r)
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Your week")
                        .font(.display(44, relativeTo: .largeTitle, weight: .heavy))
                        .tracking(-1)
                        .foregroundStyle(.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.muted)
                }
                Text(line)
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
        .accessibilityLabel("Your week: \(line)")
        .accessibilityHint("Opens your schedule")
        .accessibilityAddTraits(.isButton)
    }

    private func day(_ w: Int, _ r: Routine, isToday: Bool) -> some View {
        let type = r.weekType(w)
        return VStack(spacing: 6) {
            Text(Weekday.letters[w])
                .font(.reading(13, relativeTo: .caption).bold())
                .foregroundStyle(isToday ? Color.sky : Color.muted)
            DaySun(rise: type.hasSunrise ? 1 : 0, diameter: 26)
                .padding(.horizontal, 2)
            VStack(spacing: 1) {
                if type.hasSunrise {
                    Text(wakeTime(w, type, r))
                        .font(.reading(14, relativeTo: .footnote).bold())
                        .monospacedDigit()
                        .foregroundStyle(.ink)
                    Text(type.name)
                        .font(.reading(11, relativeTo: .caption2))
                        .foregroundStyle(.muted)
                        .opacity(type == r.firstSunrise ? 0 : 1)
                } else {
                    Text(type.name)
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

    /// "6 sunrises · 2 Gym": the sunrises, and how many are each kind other than the usual one.
    private func summary(_ r: Routine) -> String {
        let sunrises = (0...6).filter { r.weekType($0).hasSunrise }.count
        let others = r.types.filter { $0.hasSunrise && $0 != r.firstSunrise }.compactMap { t -> String? in
            let n = r.days(of: t).count
            return n > 0 ? "\(n) \(t.name)" : nil
        }
        return ([String(localized: "\(sunrises) sunrises")] + others).joined(separator: " · ")
    }
}
