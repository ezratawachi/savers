import SwiftUI

/// "Leer en": where you read, each app with its own icon. A Menu around the Picker so the row can
/// space the icon from the name; the Picker's own row glues them together.
struct ReadAppPicker: View {
    @Environment(AppStore.self) private var store
    @ScaledMetric private var iconSize = 22.0

    var body: some View {
        let current = ReadApp(store.settings.readApp)
        Menu {
            Picker("Leer en", selection: Binding { store.settings.readApp } set: { store.setReadApp($0) }) {
                ForEach(AppSettings.readApps, id: \.self) { key in
                    let app = ReadApp(key)
                    Label {
                        Text(app.name)
                    } icon: {
                        Image(app.icon).renderingMode(.original)
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
                Text("Leer en").foregroundStyle(Color.primary)
            }
        }
    }
}
