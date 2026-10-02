import SwiftUI

/// Settings › The method: the sunrise in one sentence, its four principles, its three moments with the why of
/// each step and where that comes from, and where Sunling itself comes from. The one place that names Hal Elrod.
struct MethodPage: View {
    /// A step to open the page at ("Learn more" in its card).
    var focus: Letter?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                CardSections {
                    Section {
                        Text("Each morning, six short steps to start the day with yourself before the world. Sunling rises with each one.")
                            .font(.reading(19, relativeTo: .body))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 6)
                    }

                    Section("Four principles") {
                        ForEach(Self.principles.indices, id: \.self) { i in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("\(i + 1)")
                                    .font(.display(17, relativeTo: .headline, weight: .bold))
                                    .foregroundStyle(.sky)
                                    .monospacedDigit()
                                Text(Self.principles[i])
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }

                    ForEach(Moment.allCases) { m in
                        Section {
                            ForEach(m.steps) { step($0).id($0) }
                        } header: {
                            Text("\(m.name) · \(m.about)")
                        }
                    }

                    Section {
                        Text("10, 20 or 30 minutes, always the six steps: when time is short they get shorter, never fewer. You change each step's minutes in Schedule.")
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 6)
                    } header: {
                        Text("How long")
                    }

                    Section {
                        Text("Sunling started as my way of practicing the morning routine from Hal Elrod's book *The Miracle Morning*. Over time it changed, following research and what worked in real life. Sunling isn't affiliated with Hal Elrod or The Miracle Morning.")
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 6)
                    } header: {
                        Text("Where it comes from")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(.bg)
            .onAppear {
                if let focus { proxy.scrollTo(focus, anchor: .top) }
            }
        }
        .navigationTitle("The method")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ letter: Letter) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(letter.name)
                .font(.reading(18, relativeTo: .headline).bold())
            Text(letter.how)
            Text(letter.why)
                .foregroundStyle(.muted)
            if let sources = letter.sources {
                Text(sources)
                    .font(.reading(13, relativeTo: .footnote))
                    .foregroundStyle(.muted)
                    .padding(.top, 2)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private static var principles: [String] {
        [
            String(localized: "Short every day beats long once in a while."),
            String(localized: "At your hour: your sunrise starts when you wake up, not at 5."),
            String(localized: "The path, not just the goal, and phrases you believe."),
            String(localized: "Rest counts too: a day off doesn't break anything."),
        ]
    }
}

/// "Learn more" from a step's card: The method in a sheet, opened at that step.
struct MethodSheet: View {
    let focus: Letter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MethodPage(focus: focus)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .tint(.sky)
    }
}
