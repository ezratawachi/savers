import SwiftUI

/// Historial: a month you slide between with the finger (back as far as there are records, ahead up to a
/// year), and the month's records. Tapping a day opens it.
struct HistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Grows each time the tab is chosen: the tab always opens on this month.
    let opened: Int

    @State private var path: [String] = []
    @State private var month: MonthIndex?
    @State private var heights: [MonthIndex: CGFloat] = [:]

    var body: some View {
        let current = MonthIndex(of: store.today)
        let shown = month ?? current
        let oldest = store.days.keys.min().map(MonthIndex.init(of:)) ?? current
        let first = min(oldest, current.advanced(by: -24))
        let last = current.advanced(by: 12)

        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    pager(Array(first...last), shown: shown)
                        .overlay(alignment: .topTrailing) {
                            HStack(spacing: 4) {
                                pageButton("chevron.left", "Mes anterior", to: shown.advanced(by: -1), enabled: shown > first)
                                pageButton("chevron.right", "Mes siguiente", to: shown.advanced(by: 1), enabled: shown < last)
                            }
                            .padding(.trailing, 8)
                        }
                    Group {
                        Text("El anillo se llena con cada letra. Toca un día para ver su registro o preparar uno que viene.")
                            .font(.reading(15, relativeTo: .subheadline))
                            .foregroundStyle(.muted)
                        Text("Registros del mes")
                            .font(.display(20, relativeTo: .title3))
                            .foregroundStyle(.ink)
                            .padding(.top, 6)
                            .accessibilityAddTraits(.isHeader)
                        MonthEntries(month: shown) { path.append($0) }
                            .id(shown)
                            .transition(.opacity)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 4)
                .padding(.bottom, 32)
                .animation(motion(Motion.spring), value: shown)
            }
            .background(.bg)
            .navigationTitle("Historial")
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
                    MonthGrid(month: m) { path.append($0) }
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
        .frame(height: heights[shown] ?? 400)
        .animation(motion(Motion.height), value: heights[shown])
    }

    private func pageButton(_ icon: String, _ label: String, to target: MonthIndex, enabled: Bool) -> some View {
        Button {
            withAnimation(motion(Motion.spring)) { month = target }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(enabled ? Color.sky : Color.line)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(PressScale(scale: 0.9))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func motion(_ a: Animation) -> Animation? { Motion.pick(a, reduce: reduceMotion) }
}

/// The month's records, newest first, read in full; tapping one opens its day.
private struct MonthEntries: View {
    @Environment(AppStore.self) private var store
    let month: MonthIndex
    let onOpen: (String) -> Void

    var body: some View {
        let list = month.dates.reversed().filter { store.days[$0]?.hasContent == true }
        if list.isEmpty {
            Text(month.first > store.today
                 ? "Este mes todavía no llega. Toca un día para preparar su horario."
                 : "Todavía no hay registros este mes. Marca tu primera letra en Hoy.")
                .font(.reading())
                .foregroundStyle(.muted)
        } else {
            VStack(spacing: 10) {
                ForEach(list, id: \.self) { ds in
                    Button { onOpen(ds) } label: { entry(ds, store.routine.day(ds)) }
                        .buttonStyle(PressScale(scale: 0.98))
                        .accessibilityLabel("\(DayKey.long(ds)), \(store.routine.day(ds).doneCount) de 6")
                }
            }
        }
    }

    private func entry(_ ds: String, _ d: Day) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(DayKey.short(ds)).font(.reading().bold()).foregroundStyle(.ink)
                Text("\(d.doneCount) de 6").font(.reading(15, relativeTo: .subheadline)).foregroundStyle(.muted)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.muted)
                    .opacity(0.7)
            }
            ForEach(WritingField.allCases) { f in
                if !d[f].isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.label)
                            .font(.reading(13, relativeTo: .caption).bold())
                            .foregroundStyle(.muted)
                        Text(d[f])
                            .font(.reading())
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
