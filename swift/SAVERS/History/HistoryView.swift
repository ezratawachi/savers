import SwiftUI

/// Historial: first how your mornings went, then what you wrote. The month is the title, on the night,
/// each day a little sun; you slide between months (back as far as there are records, ahead up to a
/// year). Under it, the day: "Lo que escribiste". Tapping a day opens it.
struct HistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Grows each time the tab is chosen: the tab always opens on this month.
    let opened: Int

    @State private var path: [String] = []
    @State private var month: MonthIndex?
    @State private var heights: [MonthIndex: CGFloat] = [:]
    /// The month scrolled away: the strip under the clock says which one it was.
    @State private var monthGone = false

    var body: some View {
        let current = MonthIndex(of: store.today)
        let shown = month ?? current
        let oldest = store.days.keys.min().map(MonthIndex.init(of:)) ?? current
        let first = min(oldest, current.advanced(by: -24))
        let last = current.advanced(by: 12)

        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    NightBand {
                        pager(Array(first...last), shown: shown)
                            .overlay(alignment: .topTrailing) {
                                HStack(spacing: 4) {
                                    pageButton("chevron.left", "Mes anterior", to: shown.advanced(by: -1), enabled: shown > first)
                                    pageButton("chevron.right", "Mes siguiente", to: shown.advanced(by: 1), enabled: shown < last)
                                }
                                .padding(.trailing, 8)
                                .padding(.top, 4)
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 18)
                    }
                    .onScrollVisibilityChange(threshold: 0.3) { visible in monthGone = !visible }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Lo que escribiste")
                            .font(.display(22, relativeTo: .title3))
                            .foregroundStyle(.ink)
                            .accessibilityAddTraits(.isHeader)
                        MonthWritings(month: shown) { path.append($0) }
                            .id(shown)
                            .transition(.opacity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
                .animation(motion(Motion.spring), value: shown)
            }
            .background(.bg)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                NightStrip(title: monthGone ? DayKey.monthName(shown) : nil)
            }
            .navigationDestination(for: String.self) { DayRecordView(ds: $0) }
        }
        .tint(.sky)
        .onAppear { if month == nil { month = current } }
        .onChange(of: opened) {
            if path.isEmpty { month = current }
        }
    }

    private func pager(_ months: [MonthIndex], shown: MonthIndex) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 0) {
                ForEach(months, id: \.self) { m in
                    MonthGrid(month: m, isShown: m == shown) { path.append($0) }
                        .padding(.horizontal, 16)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heights[m] = $0 }
                        .frame(maxHeight: .infinity, alignment: .top)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $month)
        .scrollIndicators(.hidden)
        .frame(height: heights[shown] ?? 420)
        .animation(motion(Motion.height), value: heights[shown])
    }

    private func pageButton(_ icon: String, _ label: String, to target: MonthIndex, enabled: Bool) -> some View {
        Button {
            withAnimation(motion(Motion.spring)) { month = target }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(enabled ? Color.sky : Color.nightLetter)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(PressScale(scale: 0.9))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func motion(_ a: Animation) -> Animation? { Motion.pick(a, reduce: reduceMotion) }
}
