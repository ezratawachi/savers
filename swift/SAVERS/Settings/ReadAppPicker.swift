import SwiftUI

/// "Read on": where you read, each app with its own icon. A Menu around the Picker so the row can
/// space the icon from the name; the Picker's own row glues them together.
struct ReadAppPicker: View {
    @Environment(AppStore.self) private var store
    @ScaledMetric private var iconSize = 22.0

    var body: some View {
        let current = ReadApp(store.settings.readApp)
        Menu {
            Picker("Read on", selection: Binding { store.settings.readApp } set: { store.setReadApp($0) }) {
                ForEach(AppSettings.readApps, id: \.self) { key in
                    let app = ReadApp(key)
                    Label {
                        Text(app.name)
                    } icon: {
                        Self.menuIcons[key]
                    }
                    .tag(key)
                }
            }
        } label: {
            LabeledContent {
                HStack(spacing: 6) {
                    Image(current.icon)
                        .resizable()
                        .frame(width: iconSize, height: iconSize)
                        .accessibilityHidden(true)
                    Text(current.name)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.medium))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(.muted)
            } label: {
                // A Menu tints its label; this row reads like the others around it.
                Text("Read on").foregroundStyle(Color.primary)
            }
        }
    }

    /// A menu shows an image at its own size, so it gets each icon redrawn at 22 pt. The assets are bigger
    /// so the row stays sharp when the text is large.
    private static let menuIcons: [String: Image] = Dictionary(uniqueKeysWithValues: AppSettings.readApps.map { key in
        let size = CGSize(width: 22, height: 22)
        let icon = UIGraphicsImageRenderer(size: size).image { _ in
            UIImage(named: ReadApp(key).icon)?.draw(in: CGRect(origin: .zero, size: size))
        }
        return (key, Image(uiImage: icon).renderingMode(.original))
    })
}
