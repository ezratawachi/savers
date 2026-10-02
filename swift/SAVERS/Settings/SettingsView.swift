import SwiftUI

/// Settings: how you want your mornings. On the night, your week (it opens Horario); under it, what you
/// say and see, help, sound and notices, your data and the language. Each page pushes in from the right.
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(CloudSync.self) private var cloud
    @Environment(Notices.self) private var notices
    @Environment(\.openURL) private var openURL
    @State private var keepMusic = ToneEngine.keepMusic
    /// The week scrolled away: the strip under the clock says where you are.
    @State private var weekGone = false
    private var gemini: GeminiVoice { .shared }

    var body: some View {
        let s = store.settings
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    NavigationLink {
                        ScheduleSettings()
                    } label: {
                        NightBand { WeekBand() }
                    }
                    .buttonStyle(CardRowButtonStyle())
                    .onScrollVisibilityChange(threshold: 0.3) { visible in weekGone = !visible }

                    CardSections {
                        Section("What you say and see") {
                            NavigationLink {
                                BreathePage()
                            } label: {
                                RowLabel(title: Letter.silencio.name, value: s.breatheLine)
                            }
                            .cardRow()
                            NavigationLink {
                                ItemsPage(kind: .affirmations)
                            } label: {
                                let n = s.affirmations.filled.count
                                RowLabel(title: Letter.afirmaciones.name, value: n > 0 ? String(localized: "\(n) phrases") : String(localized: "Empty"))
                            }
                            .cardRow()
                            NavigationLink {
                                ItemsPage(kind: .visualization)
                            } label: {
                                let n = s.visualization.items.filled.count
                                RowLabel(title: Letter.visualizacion.name, value: n > 0 ? String(localized: "\(n) questions") : String(localized: "Empty"))
                            }
                            .cardRow()
                            ReadAppPicker()
                        }
                        Section("Help") {
                            NavigationLink {
                                MethodPage()
                            } label: {
                                RowLabel(title: String(localized: "The method"))
                            }
                            .cardRow()
                            NavigationLink {
                                AssistantPage()
                            } label: {
                                RowLabel(title: String(localized: "Talk with an AI"))
                            }
                            .cardRow()
                        }
                        Section {
                            NavigationLink {
                                NoticesSettings()
                            } label: {
                                RowLabel(title: String(localized: "Notifications"), value: notices.anyOn ? String(localized: "On") : String(localized: "Off"))
                            }
                            .cardRow()
                            NavigationLink {
                                VoiceSettings()
                            } label: {
                                RowLabel(title: String(localized: "Voice"), value: gemini.hasKey ? gemini.voice : String(localized: "iPhone"))
                            }
                            .cardRow()
                            Toggle("Keep my music", isOn: $keepMusic)
                                .tint(.sky)
                                .onChange(of: keepMusic) { _, on in ToneEngine.keepMusic = on }
                        } header: {
                            Text("Sound and notifications")
                        } footer: {
                            Text(keepMusic
                                 ? "Your music keeps playing during the timers; you hear the voice if the iPhone isn't on silent."
                                 : "The voice pauses your music and always plays.")
                        }
                        Section {
                            NavigationLink {
                                BackupPage()
                            } label: {
                                RowLabel(title: String(localized: "Backup"), value: cloud.linked ? String(localized: "In the cloud") : String(localized: "backup.off", defaultValue: "Off"))
                            }
                            .cardRow()
                        } header: {
                            Text("Your data")
                        } footer: {
                            Text(cloud.linked ? "Your records are saved on this device and in the cloud." : "Your records live only on this device.")
                        }
                        Section {
                            // Apple's way: the iPhone's language, or one just for Sunling in its page of iOS Settings.
                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            } label: {
                                RowLabel(title: String(localized: "Language"), value: AppLanguage.name)
                            }
                            .cardRow()
                            .accessibilityHint("Opens Sunling in the iPhone's Settings")
                        } footer: {
                            Text("Sunling speaks the iPhone's language. To choose another one just for Sunling, tap Language in its Settings.")
                        }
                        #if DEBUG
                        DeveloperSection()
                        #endif
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
            .background(.bg)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                NightStrip(title: weekGone ? String(localized: "Settings") : nil)
            }
        }
    }
}
