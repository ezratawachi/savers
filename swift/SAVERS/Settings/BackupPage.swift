import AuthenticationServices
import SwiftUI

/// Settings › Backup: the cloud.
struct BackupPage: View {
    @Environment(AppStore.self) private var store
    @Environment(CloudSync.self) private var cloud
    @Environment(\.webAuthenticationSession) private var webAuth
    @State private var askingSignOut = false

    var body: some View {
        CardList {
            cloudSection
        }
        .navigationTitle("Backup")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Sign out?", isPresented: $askingSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { cloud.signOut() }
        } message: {
            Text("Your records stay on this device, but stop being saved to the cloud.")
        }
    }

    @ViewBuilder
    private var cloudSection: some View {
        if cloud.linked {
            Section {
                TimelineView(.periodic(from: .now, by: 30)) { t in
                    LabeledContent("Status") {
                        Text(cloud.statusLabel(now: t.date))
                            .foregroundStyle(cloud.error.isEmpty ? Color.muted : Color.warn)
                    }
                }
                if let email = cloud.email, !email.isEmpty {
                    LabeledContent("Account", value: email)
                }
                Button("Sign out", role: .destructive) { askingSignOut = true }
                    .foregroundStyle(.warn)
                    .cardRow()
            } header: {
                Text("Cloud")
            } footer: {
                Text("It saves by itself. If you change the same thing on the iPhone and on the Mac, the last change stays.")
            }
        } else {
            Section {
                Button {
                    Task { await cloud.signIn(using: webAuth) }
                } label: {
                    HStack {
                        Text("Sign in with Google").bold()
                        if cloud.busy { Spacer(); ProgressView() }
                    }
                }
                .foregroundStyle(.sky)
                .disabled(cloud.busy)
                .cardRow()
            } header: {
                Text("Cloud")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if !cloud.error.isEmpty { Text(cloud.error).foregroundStyle(.warn) }
                    Text("Your records save themselves to the cloud, and you see them on the Mac too. Only your Google account can open them.")
                }
            }
        }
    }
}
