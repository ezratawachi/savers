import SwiftUI

/// Visualización: the questions, one minute each.
struct VisualizationBody: View {
    let visualization: Visualization
    let done: Bool
    /// "Agregar preguntas" when there are none.
    let onAdd: () -> Void

    var body: some View {
        let items = visualization.items.filled
        VStack(alignment: .leading, spacing: 10) {
            if items.isEmpty {
                Text("Todavía no tienes preguntas.")
                Button("Agregar preguntas", action: onAdd)
                    .buttonStyle(PrimaryButton())
            } else {
                VisualizationTimer(done: done)
                    .padding(.bottom, 4)
                ForEach(items.indices, id: \.self) { i in
                    let item = items[i]
                    let label = item.label.trimmingCharacters(in: .whitespaces)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(i + 1).")
                            .monospacedDigit()
                            .foregroundStyle(.muted)
                        if label.isEmpty {
                            Text(item.text)
                        } else {
                            Text("\(Text(label + ":").bold()) \(item.text)")
                        }
                    }
                }
                if !visualization.note.trimmingCharacters(in: .whitespaces).isEmpty {
                    Note(visualization.note)
                }
            }
        }
        .font(.reading())
        .foregroundStyle(.ink)
    }
}
