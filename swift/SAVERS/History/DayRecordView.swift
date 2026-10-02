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
    /// The big date scrolled away: then the bar shows the short one, so the date is never there twice.
    @State private var headerGone = false
    @FocusState private var focus: WritingField?

    var body: some View {
        let r = store.routine
        let type = r.dayType(ds)
        let d = r.day(ds)
        let future = ds > store.today
        let showRoutine = type.hasSavers || (type == .off && (d.extra || d.hasContent))

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NightBand {
                    header(r, type: type, d: d, future: future, showRoutine: showRoutine)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
                VStack(alignment: .leading, spacing: 18) {
                    if future && type != .shabbat {
                        DayEditor(ds: ds)
                    } else if type == .shabbat {
                        RestCard(title: "Shabbat Shalom", text: "Shabbat no tiene registro.")
                    } else if !showRoutine {
                        RestCard(
                            title: "Descanso",
                            text: "Ese día Sunling descansaba. Si igual hiciste tu amanecer, puedes registrarlo.",
                            button: ("Registrar mi amanecer", { withAnimation(motion(Motion.spring)) { store.doSaversAnyway(on: ds) } })
                        )
                    } else {
                        letters(r, d)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
        }
        .background(.bg)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(DayKey.short(ds))
        .navigationBarTitleDisplayMode(.inline)
        // The bar is the night too, so it runs on into the band and stays when the day scrolls under it.
        .toolbarBackground(Color.night, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(DayKey.short(ds))
                    .font(.display(18, relativeTo: .headline, weight: .bold))
                    .foregroundStyle(.ink)
                    .environment(\.colorScheme, .dark)
                    .opacity(headerGone ? 1 : 0)
                    .animation(motion(.easeOut(duration: 0.2)), value: headerGone)
                    .accessibilityHidden(!headerGone)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: checkTick)
        .daySheet($sheetDay)
    }

    /// The date, what the day was and how far it went, and Sunling as that morning left him: up and
    /// awake if it was complete, heavy-eyed if not, asleep on a day to come or of rest.
    private func header(_ r: Routine, type: DayType, d: Day, future: Bool, showRoutine: Bool) -> some View {
        let asleep = future || type == .shabbat || !showRoutine
        let pose = asleep ? SunlingPose.asleep : .morning(d.doneCount)
        return VStack(alignment: .leading, spacing: 10) {
            Text(DayKey.long(ds))
                .font(.display(32, relativeTo: .largeTitle))
                .tracking(-0.5)
                .foregroundStyle(.ink)
                .accessibilityAddTraits(.isHeader)
                .onScrollVisibilityChange(threshold: 0.2) { visible in headerGone = !visible }
            ZStack(alignment: .topLeading) {
                Color.clear.frame(height: 64)
                if !(future && type != .shabbat) {
                    HStack(spacing: 8) {
                        DayChip(type: type) { sheetDay = ds }
                        if showRoutine {
                            Text("· \(d.doneCount) de 6")
                                .font(.reading(15, relativeTo: .subheadline))
                                .foregroundStyle(.muted)
                        }
                    }
                } else {
                    Text("Todavía no amanece")
                        .font(.reading(16, relativeTo: .subheadline))
                        .foregroundStyle(.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottomTrailing) {
                Sunling(pose: pose, lit: !asleep && d.doneCount == 6)
                    .frame(width: 104)
                    .padding(.trailing, -10)
                    .animation(motion(Motion.sun), value: pose)
            }
        }
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
        // A 44-pt target without making the chip look bigger.
        .padding(.vertical, 5)
        .contentShape(.rect)
        .padding(.vertical, -5)
    }
}
