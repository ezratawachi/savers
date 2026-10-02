#if DEBUG
import SwiftUI

/// Settings' last section, only in Debug builds: into the developer mode, and out of it.
struct DeveloperSection: View {
    @Environment(DevMode.self) private var devMode
    @State private var askingOver = false

    var body: some View {
        Section {
            if devMode.on {
                Button("Start from zero") { askingOver = true }
                    .foregroundStyle(.sky)
                    .cardRow()
                    .confirmationDialog("Start the test app from zero?", isPresented: $askingOver, titleVisibility: .visible) {
                        Button("Start from zero", role: .destructive) { devMode.startOver() }
                    } message: {
                        Text("What you did in developer mode is erased and the welcome shows again. Your real app isn't touched.")
                    }
                Button("Exit developer mode") { devMode.exit() }
                    .foregroundStyle(.sky)
                    .cardRow()
            } else {
                Button("Developer mode") { devMode.enter() }
                    .foregroundStyle(.sky)
                    .cardRow()
            }
        } header: {
            Text("Developer")
        } footer: {
            Text(devMode.on
                 ? "You're in the test app. It stays until you exit, even if you close Sunling."
                 : "Sunling as a new install of its own, to live what someone new sees. Your data, notices, cloud and voice aren't touched. Only in the version installed from the Mac.")
        }
    }
}
#endif
