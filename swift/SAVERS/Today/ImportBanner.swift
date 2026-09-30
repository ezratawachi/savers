import SwiftUI

/// Shown until there's a name, a schedule or an affirmation on this iPhone, and it isn't signed in.
struct ImportBanner: View {
    let busy: Bool
    let error: String
    let onSignIn: () -> Void
    let onImport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Entra con Google o importa tu copia para cargar tus afirmaciones y horario.")
                    .foregroundStyle(.ink)
                if !error.isEmpty {
                    Text(error).foregroundStyle(.warn)
                }
            }
            .font(.reading(15, relativeTo: .subheadline))
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                Button("Entrar", action: onSignIn)
                    .disabled(busy)
                Button("Importar", action: onImport)
            }
            .font(.reading(16).bold())
            .foregroundStyle(.sky)
            .buttonStyle(.borderless)
            .frame(minHeight: 44)
        }
        .padding(CardLayout.inset)
        .background(.surface2, in: .rect(cornerRadius: CardLayout.radius))
    }
}
