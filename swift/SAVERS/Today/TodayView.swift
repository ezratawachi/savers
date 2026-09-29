import AuthenticationServices
import SwiftUI

/// Hoy: the day's guide. Letters by the schedule's blocks, "Ahora" on the first one left, and the two finishes.
struct TodayView: View {
    @Environment(AppStore.self) private var store
    @Environment(CloudSync.self) private var cloud
    @Environment(\.webAuthenticationSession) private var webAuth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Every card starts closed; this remembers the ones opened while the app stays open.
    @State private var openCards: Set<Letter> = []
    /// "Ahora" and the finish move a beat after a letter is marked, so each change is seen on its own.
    @State private var shownNow: Letter?
    @State private var shownFinish: Finish = .none
    @State private var settled = false
    @State private var foldOpen = false
    @State private var isScrolling = false
    @State private var importing = false
    @State private var checkTick = 0
    @State private var finishTick = 0
    /// Set when a letter is marked here, so "Ahora" only opens and scrolls to the next card after that
    /// (not after an import or a change from the cloud).
    @State private var justMarked = false
    /// The cards shown whole on screen, to scroll only when the next one isn't.
    @State private var fullyVisible: Set<Letter> = []
    @FocusState private var focus: WritingField?

    var body: some View {
        let routine = store.routine
        let ds = store.today
        let type = routine.dayType(ds)
        let day = routine.day(ds)
        let blocks = routine.blocks(ds)
        let now = routine.nextLetter(blocks, day)
        let finish = routine.finish(ds)

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TodayHeader(ds: ds, name: store.settings.name, type: type, status: store.saveError)
                    if !store.settings.hasPersonalData && !cloud.linked {
                        ImportBanner(busy: cloud.busy, error: cloud.error) {
                            Task { await cloud.signIn(using: webAuth) }
                        } onImport: {
                            importing = true
                        }
                    }
                    if type == .shabbat {
                        RestCard(title: "Shabbat Shalom", text: "Hoy no hay registro. Nos vemos el domingo.")
                    } else if type == .off && !(day.extra || store.showOff || day.hasContent) {
                        RestCard(
                            title: "Sin SAVERS",
                            text: "Hoy no toca SAVERS. Si quieres, puedes hacerlos igual y quedan registrados.",
                            button: ("Hacer mis SAVERS hoy", { withAnimation(motion(Motion.spring)) { store.doSaversAnyway(on: ds) } })
                        )
                    } else {
                        guide(routine, ds: ds, day: day, blocks: blocks)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(.bg)
            .safeAreaInset(edge: .top, spacing: 0) {
                // Content scrolls under the clock without showing through it.
                Color.clear.frame(height: 0).background(.bg)
            }
            .scrollDismissesKeyboard(.interactively)
            .onScrollPhaseChange { _, phase in isScrolling = phase != .idle }
            .task(id: now) { await moveNow(to: now, routine: routine, proxy: proxy) }
            .task(id: FinishKey(finish: finish, writing: focus != nil)) { await moveFinish(to: finish) }
            .onChange(of: focus) { _, new in
                guard let new else { return }
                // Keep the field you're writing in above the keyboard.
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    withAnimation(motion(Motion.spring)) { proxy.scrollTo(new, anchor: UnitPoint(x: 0.5, y: 0.35)) }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: checkTick)
        .sensoryFeedback(.success, trigger: finishTick)
        .backupImporter(isPresented: $importing)
        .onChange(of: store.today) {
            // A new day starts like the app does: everything closed, nothing animated.
            let fresh = store.routine
            openCards = []
            foldOpen = false
            shownNow = fresh.nextLetter(fresh.blocks(fresh.today), fresh.day(fresh.today))
            shownFinish = fresh.finish(fresh.today)
        }
        .onChange(of: focus) { _, new in
            // Leaving a field of a card that's already done closes it.
            if new == nil && routine.day(ds).isDone(.escritura) {
                withAnimation(motion(Motion.height)) { _ = openCards.remove(.escritura) }
            }
        }
    }

    // MARK: The guide

    @ViewBuilder
    private func guide(_ routine: Routine, ds: String, day: Day, blocks: [Block]) -> some View {
        let fin = shownFinish
        let folded = fin == .none ? [] : blocks.filter { fin == .day || !$0.isLater }
        let rest = blocks.filter { b in !folded.contains(b) }

        if fin != .none {
            FinishCard(finish: fin, pending: pending(blocks, day), streak: routine.streak())
                .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
        }
        HeroLetters(day: day, streak: routine.streak(), showStreak: fin != .day)
        VStack(alignment: .leading, spacing: 8) {
            if !folded.isEmpty {
                let label = fin == .day && blocks.contains(where: \.isLater) ? "Todo el día" : "Mañana"
                FoldCard(label: label, count: folded.reduce(0) { $0 + $1.letters.count }, isOpen: $foldOpen) {
                    blockList(folded, routine, ds: ds, day: day)
                }
                .transition(.opacity)
            }
            blockList(rest, routine, ds: ds, day: day)
        }
    }

    private func blockList(_ blocks: [Block], _ routine: Routine, ds: String, day: Day) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(blocks) { block in
                if let head = block.head { BlockHeader(head: head) }
                ForEach(block.letters) { letter in
                    card(letter, routine, ds: ds, day: day)
                        .id(letter)
                        .onScrollVisibilityChange(threshold: 0.98) { visible in
                            if visible { fullyVisible.insert(letter) } else { fullyVisible.remove(letter) }
                        }
                }
            }
        }
    }

    private func card(_ letter: Letter, _ routine: Routine, ds: String, day: Day) -> some View {
        let reviewDue = routine.affirmationReviewDue(reviewed: store.affReviewed)
        let info = routine.info(letter, on: ds, reviewDue: reviewDue)
        let isNow = letter == shownNow
        return LetterCard(
            letter: letter,
            info: info,
            done: day.isDone(letter),
            isNow: isNow,
            isOpen: info.opens && openCards.contains(letter),
            sun: isNow ? routine.sunPlan(letter) : nil,
            sunNext: isNow ? routine.sunNext(after: letter) : "",
            onToggle: { toggle(letter, ds: ds) },
            onOpen: {
                withAnimation(motion(Motion.height)) {
                    if openCards.contains(letter) { openCards.remove(letter) } else { openCards.insert(letter) }
                }
            }
        ) {
            cardBody(letter, routine, ds: ds, day: day, reviewDue: reviewDue)
        }
    }

    @ViewBuilder
    private func cardBody(_ letter: Letter, _ routine: Routine, ds: String, day: Day, reviewDue: Bool) -> some View {
        let kind = routine.scheduleKind(ds)
        switch letter {
        case .afirmaciones:
            AffirmationsBody(items: routine.settings.affirmations.filled, reviewDue: reviewDue)
        case .visualizacion:
            VisualizationBody(visualization: routine.settings.visualization, done: day.isDone(.visualizacion))
        case .lectura:
            ReadingBody(
                minutes: routine.letterMinutes(.lectura, kind, on: ds),
                gym: kind == .gym,
                laterAt: kind == .gym ? routine.laterTime(.gym, .lectura, on: ds) : "",
                gymReading: routine.settings.schedule?.gymReading,
                done: day.isDone(.lectura)
            )
        case .escritura:
            WritingBody(ds: ds, gym: routine.dayType(ds) == .gym, done: day.isDone(.escritura), focus: $focus) {
                focus = nil
                if !store.routine.day(ds).isDone(.escritura) { toggle(.escritura, ds: ds) }
            }
        case .ejercicio:
            if kind != .gym { ExerciseTimer(done: day.isDone(.ejercicio)) }
        case .silencio:
            EmptyView()
        }
    }

    /// "Lectura a las 8:50 pm": what "Más tarde" still holds.
    private func pending(_ blocks: [Block], _ day: Day) -> String {
        blocks.filter(\.isLater).compactMap { b -> String? in
            let names = b.letters.filter { !day.isDone($0) }.map(\.name)
            guard !names.isEmpty else { return nil }
            let at = b.head.flatMap { $0.count > 1 && !$0[1].isEmpty ? " a las \($0[1])" : nil } ?? ""
            return names.joined(separator: " y ") + at
        }.joined(separator: ", ")
    }

    // MARK: Marking

    private func toggle(_ letter: Letter, ds: String) {
        var on = false
        withAnimation(motion(Motion.height)) {
            on = store.toggle(letter, on: ds)
            if on { openCards.remove(letter) }
        }
        justMarked = true
        checkTick += 1
        guard on else { return }
        if store.routine.finish(ds) != .none {
            Sounds.complete()
        } else {
            Sounds.check()
        }
    }

    /// A beat after the marked card settles, "Ahora" moves on; the next card opens if it has something
    /// inside and comes into view, unless you're scrolling.
    private func moveNow(to now: Letter?, routine: Routine, proxy: ScrollViewProxy) async {
        guard settled else {
            shownNow = now
            shownFinish = routine.finish(store.today)
            settled = true
            return
        }
        guard now != shownNow else { return }
        let marked = justMarked
        justMarked = false
        guard marked else {
            shownNow = now
            return
        }
        try? await Task.sleep(for: reduceMotion ? .zero : .milliseconds(150))
        guard !Task.isCancelled else { return }
        withAnimation(motion(Motion.height)) {
            shownNow = now
            if let now, routine.info(now, on: store.today, reviewDue: false).opens, !routine.day(store.today).isDone(now) {
                openCards.insert(now)
            }
        }
        guard let now, !isScrolling else { return }
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled, !isScrolling, !fullyVisible.contains(now) else { return }
        withAnimation(motion(Motion.spring)) { proxy.scrollTo(now, anchor: UnitPoint(x: 0.5, y: 0.04)) }
    }

    /// Reaching a finish: 400 ms later, what's done folds into one row and the finish card grows.
    /// Going back (unmarking) is immediate. Not while you're writing.
    private func moveFinish(to finish: Finish) async {
        guard settled, finish != shownFinish else { return }
        if finish < shownFinish {
            withAnimation(motion(Motion.height)) { shownFinish = finish }
            return
        }
        guard focus == nil else { return }
        try? await Task.sleep(for: reduceMotion ? .zero : .milliseconds(400))
        guard !Task.isCancelled else { return }
        foldOpen = false
        withAnimation(motion(Motion.spring)) { shownFinish = finish }
        finishTick += 1
    }

    private func motion(_ animation: Animation) -> Animation? { Motion.pick(animation, reduce: reduceMotion) }
}

private struct FinishKey: Hashable {
    let finish: Finish
    let writing: Bool
}
