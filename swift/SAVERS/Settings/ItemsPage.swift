import SwiftUI

/// Settings › Affirm or Imagine: read, and Edit. While editing, Cancel and Done take the place of going
/// back.
struct ItemsPage: View {
    @Environment(AppStore.self) private var store
    @Environment(Toast.self) private var toast
    let kind: ItemsKind
    @State private var editing = false
    /// Kept apart from `editing`: the list being edited can still read it while it goes away.
    @State private var draft = ItemsDraft(.affirmations, AppSettings())
    @State private var askingDiscard = false

    var body: some View {
        Group {
            if editing {
                ItemsEditor(kind: kind, draft: $draft)
            } else {
                ItemsReader(kind: kind, settings: store.settings)
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(editing)
        .toolbar {
            if editing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                        .confirmationDialog("Discard your changes?", isPresented: $askingDiscard, titleVisibility: .visible) {
                            Button("Discard changes", role: .destructive) { editing = false }
                            Button("Keep editing", role: .cancel) {}
                        }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let message = store.save(draft, kind, inReview: false) { toast.show(message) }
                        editing = false
                    }
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        draft = ItemsDraft(kind, store.settings)
                        editing = true
                    }
                }
            }
        }
    }

    /// Nothing changed: back to reading. Something did: ask first.
    private func cancel() {
        if draft.differs(from: store.settings, kind) { askingDiscard = true } else { editing = false }
    }
}

/// From Today: "Review affirmations" (the monthly review: Affirm, then Imagine), or "Add" when a card is
/// empty. Opens already editing; closing returns to the same spot in Today.
struct ItemsSheet: View {
    enum Mode: String, Identifiable {
        case review, affirmations, visualization
        var id: String { rawValue }
    }

    @Environment(AppStore.self) private var store
    @Environment(Toast.self) private var toast
    @Environment(\.dismiss) private var dismiss
    let mode: Mode

    @State private var path: [ItemsKind] = []
    @State private var aff: ItemsDraft
    @State private var vis: ItemsDraft
    @State private var askingDiscard = false

    init(mode: Mode, settings: AppSettings) {
        self.mode = mode
        _aff = State(initialValue: ItemsDraft(.affirmations, settings))
        _vis = State(initialValue: ItemsDraft(.visualization, settings))
    }

    var body: some View {
        NavigationStack(path: $path) {
            page(mode == .visualization ? .visualization : .affirmations)
                .navigationDestination(for: ItemsKind.self) { page($0) }
        }
        .tint(.sky)
        .interactiveDismissDisabled(changed)
    }

    private func page(_ kind: ItemsKind) -> some View {
        let next = mode == .review && kind == .affirmations
        return ItemsEditor(kind: kind, draft: kind == .affirmations ? $aff : $vis)
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // In the review, Cancel ends it where it is.
                    Button("Cancel", action: cancel)
                        .confirmationDialog("Discard your changes?", isPresented: $askingDiscard, titleVisibility: .visible) {
                            Button("Discard changes", role: .destructive) { dismiss() }
                            Button("Keep editing", role: .cancel) {}
                        }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(next ? "Next" : "Done") { done(kind, next: next) }
                }
            }
    }

    private var changed: Bool {
        aff.differs(from: store.settings, .affirmations) || vis.differs(from: store.settings, .visualization)
    }

    private func cancel() {
        if changed { askingDiscard = true } else { dismiss() }
    }

    private func done(_ kind: ItemsKind, next: Bool) {
        let message = store.save(kind == .affirmations ? aff : vis, kind, inReview: mode == .review)
        if next {
            // What was saved, as saved (empty lines dropped), so going on doesn't count as a change.
            aff = ItemsDraft(.affirmations, store.settings)
            vis = ItemsDraft(.visualization, store.settings)
            path.append(.visualization)
            return
        }
        if mode == .review {
            toast.show(String(localized: "Monthly review done"))
        } else if let message {
            toast.show(message)
        }
        dismiss()
    }
}
