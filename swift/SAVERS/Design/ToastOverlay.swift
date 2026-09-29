import SwiftUI

/// Shows the toast above the tab bar and reads it out with VoiceOver.
struct ToastOverlay: View {
    @Environment(Toast.self) private var toast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            Spacer()
            if let message = toast.message {
                Text(message)
                    .font(.reading(16).bold())
                    .foregroundStyle(.bg)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.ink, in: .capsule)
                    .padding(.bottom, 64)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(Motion.pick(Motion.spring, reduce: reduceMotion), value: toast.message)
        .allowsHitTesting(false)
        .onChange(of: toast.message) { _, new in
            if let new { AccessibilityNotification.Announcement(new).post() }
        }
    }
}
