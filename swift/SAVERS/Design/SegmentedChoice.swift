import SwiftUI

/// A segmented control whose segments can carry a second line ("los martes", "lun, mar, jue"),
/// which the system one can't. The chosen segment slides under the finger's choice.
struct SegmentedChoice<ID: Hashable>: View {
    struct Option: Identifiable {
        let id: ID
        let title: String
        var note: String?
    }

    let label: String
    let options: [Option]
    @Binding var selection: ID

    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// The chosen segment stands out lighter than its track, like iOS's own: white in light, a lifted blue in dark.
    private var chosenFill: Color { colorScheme == .dark ? .line : .surface }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { o in
                let on = o.id == selection
                Button {
                    guard !on else { return }
                    withAnimation(Motion.pick(Motion.spring, reduce: reduceMotion)) { selection = o.id }
                } label: {
                    VStack(spacing: 1) {
                        Text(o.title)
                            .font(.reading(15, relativeTo: .subheadline).bold())
                            .foregroundStyle(.ink)
                        if let note = o.note {
                            Text(note)
                                .font(.reading(12, relativeTo: .caption))
                                .foregroundStyle(.muted)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .padding(.vertical, 3)
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(chosenFill)
                                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                .matchedGeometryEffect(id: "on", in: ns)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Color.surface2, in: .rect(cornerRadius: 11))
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}
