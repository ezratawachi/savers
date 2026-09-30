import SwiftUI

/// The day chip opens this: what the day is and its hours.
struct DaySheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let ds: String

    var body: some View {
        NavigationStack {
            ScrollView {
                DayEditor(ds: ds)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .background(.bg)
            .navigationTitle(ds == store.today ? "Hoy" : DayKey.short(ds))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .tint(.sky)
    }
}

extension View {
    /// Opens the day sheet for a date while it's set.
    func daySheet(_ ds: Binding<String?>) -> some View {
        sheet(item: Binding { ds.wrappedValue.map(SheetDate.init) } set: { ds.wrappedValue = $0?.id }) { d in
            DaySheet(ds: d.id)
        }
    }
}

private struct SheetDate: Identifiable {
    let id: String
}
