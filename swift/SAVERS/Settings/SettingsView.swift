import SwiftUI

/// Ajustes: how you want your mornings. On the night, your week (it opens Horario); under it, what you
/// say and see, help, sound and notices, and your data. Each page pushes in from the right.
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(CloudSync.self) private var cloud
    @Environment(Notices.self) private var notices
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
                        Section("Lo que dices y ves") {
                            NavigationLink {
                                BreathePage()
                            } label: {
                                RowLabel(title: "Respira", value: s.breatheLine)
                            }
                            .cardRow()
                            NavigationLink {
                                ItemsPage(kind: .affirmations)
                            } label: {
                                let n = s.affirmations.filled.count
                                RowLabel(title: Letter.afirmaciones.name, value: n > 0 ? count(n, "frase", "frases") : "Vacío")
                            }
                            .cardRow()
                            NavigationLink {
                                ItemsPage(kind: .visualization)
                            } label: {
                                let n = s.visualization.items.filled.count
                                RowLabel(title: Letter.visualizacion.name, value: n > 0 ? count(n, "pregunta", "preguntas") : "Vacío")
                            }
                            .cardRow()
                            ReadAppPicker()
                        }
                        Section("Ayuda") {
                            NavigationLink {
                                AssistantPage()
                            } label: {
                                RowLabel(title: "Hablar con una IA")
                            }
                            .cardRow()
                        }
                        Section {
                            NavigationLink {
                                NoticesSettings()
                            } label: {
                                RowLabel(title: "Notificaciones", value: notices.anyOn ? "Activadas" : "Apagadas")
                            }
                            .cardRow()
                            NavigationLink {
                                VoiceSettings()
                            } label: {
                                RowLabel(title: "Voz", value: gemini.hasKey ? gemini.voice : "Del iPhone")
                            }
                            .cardRow()
                            Toggle("Mantener mi música", isOn: $keepMusic)
                                .tint(.sky)
                                .onChange(of: keepMusic) { _, on in ToneEngine.keepMusic = on }
                        } header: {
                            Text("Sonido y avisos")
                        } footer: {
                            Text(keepMusic
                                 ? "Tu música sigue en los temporizadores; la voz se oye si el iPhone no está en silencio."
                                 : "La voz pausa tu música y suena siempre.")
                        }
                        Section {
                            NavigationLink {
                                BackupPage()
                            } label: {
                                RowLabel(title: "Copia de seguridad", value: cloud.linked ? "En la nube" : "Apagada")
                            }
                            .cardRow()
                        } header: {
                            Text("Tus datos")
                        } footer: {
                            Text(cloud.linked ? "Tus registros se guardan en este aparato y en la nube." : "Tus registros viven solo en este aparato.")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
            .background(.bg)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                NightStrip(title: weekGone ? "Ajustes" : nil)
            }
        }
    }

    private func count(_ n: Int, _ one: String, _ many: String) -> String { "\(n) \(n == 1 ? one : many)" }
}
