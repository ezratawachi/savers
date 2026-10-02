import SwiftUI

/// `Section`s drawn with Hoy's pieces: a header like a block's, the rows in one card (CardLayout's
/// corners and line, rows apart by a hairline), and a quiet footer. iOS's own controls stay inside.
struct CardSections<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            ForEach(sections: content) { section in
                if !section.content.isEmpty || !section.header.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        if !section.header.isEmpty {
                            section.header
                                .font(.reading(15, relativeTo: .subheadline).bold())
                                .foregroundStyle(.muted)
                                .padding(.horizontal, 4)
                                .accessibilityAddTraits(.isHeader)
                        }
                        if section.containerValues.cardPlain {
                            section.content
                        } else if !section.content.isEmpty {
                            card(section.content)
                        }
                        if !section.footer.isEmpty {
                            section.footer
                                .font(.reading(14, relativeTo: .footnote))
                                .foregroundStyle(.muted)
                                .padding(.horizontal, 4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .font(.reading())
        .foregroundStyle(.ink)
        .labeledContentStyle(CardLabeledContentStyle())
        .buttonStyle(CardRowButtonStyle())
    }

    private func card(_ rows: SubviewsCollection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows.indices, id: \.self) { i in
                if i > 0 {
                    Rectangle()
                        .fill(Color.line)
                        .frame(height: 1)
                        .padding(.leading, CardLayout.inset)
                }
                let row = rows[i]
                if row.containerValues.cardRowPadded {
                    row
                } else {
                    row
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: CardLayout.rowHeight, alignment: .leading)
                        .padding(.horizontal, CardLayout.inset)
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: CardLayout.radius)
                .fill(Color.surface)
                .stroke(Color.line, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: CardLayout.radius))
    }
}

/// Sections in a scrolling page with the day's background: Ajustes' pages.
struct CardList<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            CardSections { content }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
        }
        .background(.bg)
        .scrollDismissesKeyboard(.interactively)
    }
}

extension ContainerValues {
    /// A section shown as is, with no card around it (a segmented choice).
    @Entry var cardPlain = false
    /// A row that pads itself, so all of it is the button.
    @Entry var cardRowPadded = false
}

extension View {
    /// A tappable row: the whole row is the target, and it dims while pressed.
    func cardRow() -> some View {
        buttonStyle(CardRowButtonStyle(padded: true))
            .containerValue(\.cardRowPadded, true)
    }

    /// A section with no card.
    func cardPlain() -> some View {
        containerValue(\.cardPlain, true)
    }
}
