import SwiftUI

/// A day opened from Historial. A past day is a record: letters can be marked or unmarked, and only
/// Escritura opens. A day to come is only what it will be and its hours.
struct DayRecordView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let ds: String

    @State private var writingOpen = false
    @State private var sheetDay: String?
    @State private var checkTick = 0
    @FocusState private var focus: WritingField?

    var body: some View {
        let r = store.routine
        let type = r.dayType(ds)
        let d = r.day(ds)
        let future = ds > store.today
        let showRoutine = type.hasSavers || (type == .off && (d.extra || d.hasContent))

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(DayKey.long(ds))
                        .font(.display(30, relativeTo: .largeTitle))
                        .foregroundStyle(.ink)
                        .accessibilityAddTraits(.isHeader)
                    if !(future && type != .shabbat) {
                        HStack(spacing: 8) {
                            DayChip(type: type) { sheetDay = ds }
                            if showRoutine {
                                Text("· \(d.doneCount) de 6")
                                    .font(.reading(15, relativeTo: .subheadline))
                                    .foregroundStyle(.muted)
                            }
                        }
                    }
                }
                if future && type != .shabbat {
                    DayEditor(ds: ds)
                } else if type == .shabbat {
                    RestCard(title: "Shabbat Shalom", text: "Shabbat no tiene registro.")
                } else if !showRoutine {
                    RestCard(
                        title: "Sin SAVERS",
                        text: "Ese día no tocaba SAVERS. Si igual los hiciste, puedes registrarlos.",
                        button: ("Registrar mis SAVERS", { withAnimation(motion(Motion.spring)) { store.doSaversAnyway(on: ds) } })
                    )
                } else {
                    letters(r, d)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(.bg)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(DayKey.short(ds))
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: checkTick)
        .daySheet($sheetDay)
    }

    private func letters(_ r: Routine, _ d: Day) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(r.blocks(ds)) { block in
                if let head = block.head { BlockHeader(head: head) }
                ForEach(block.letters) { letter in
                    card(letter, r, d)
                }
            }
        }
    }

    private func card(_ letter: Letter, _ r: Routine, _ d: Day) -> some View {
        var info = r.info(letter, on: ds, reviewDue: false)
        // A day to look at, not a morning to run again: only Escritura opens.
        info.opens = letter == .escritura
        return LetterCard(
            letter: letter,
            info: info,
            done: d.isDone(letter),
            isNow: false,
            isOpen: info.opens && writingOpen,
            sun: nil,
            sunNext: "",
            onToggle: { toggle(letter) },
            onOpen: { withAnimation(motion(Motion.height)) { writingOpen.toggle() } }
        ) {
            if letter == .escritura {
                WritingBody(ds: ds, gym: r.dayType(ds) == .gym, done: d.isDone(.escritura), focus: $focus) {
                    focus = nil
                    if !store.routine.day(ds).isDone(.escritura) { toggle(.escritura) }
                    withAnimation(motion(Motion.height)) { writingOpen = false }
                }
            }
        }
    }

    private func toggle(_ letter: Letter) {
        var on = false
        withAnimation(motion(Motion.height)) { on = store.toggle(letter, on: ds) }
        checkTick += 1
        if on { Sounds.check() }
    }

    private func motion(_ a: Animation) -> Animation? { Motion.pick(a, reduce: reduceMotion) }
}

/// "Día normal ›": what the day is; a button that opens its sheet, except on Shabbat.
struct DayChip: View {
    let type: DayType
    let action: () -> Void

    var body: some View {
        if type == .shabbat {
            label(chevron: false)
        } else {
            Button(action: action) { label(chevron: true) }
                .buttonStyle(PressScale())
                .accessibilityLabel("\(type.chipName). Cambiar este día")
        }
    }

    private func label(chevron: Bool) -> some View {
        HStack(spacing: 4) {
            Text(type.chipName)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.muted)
            }
        }
        .font(.reading(15, relativeTo: .subheadline).bold())
        .foregroundStyle(.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.surface2, in: .capsule)
    }
}
