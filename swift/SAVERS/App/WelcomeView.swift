import AuthenticationServices
import SwiftUI

/// A new install's three screens, on the launch's own night: what Sunling is, when you wake up and for how
/// long, and the notifications. Sunling sleeps on the horizon in the middle and wakes a little with each
/// screen; the opening curtain under this draws him, so when the welcome ends he lands on Today as on any open.
struct WelcomeView: View {
    /// Settings › The method › "See the welcome": the same screens, on their own night, changing nothing.
    var preview = false

    @Environment(AppStore.self) private var store
    @Environment(CloudSync.self) private var cloud
    @Environment(Notices.self) private var notices
    @Environment(Opening.self) private var opening
    @Environment(\.webAuthenticationSession) private var webAuth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page = 0
    @State private var wake = "6:30"
    @State private var length = SunriseLength.ten
    @State private var asking = false
    @State private var pose = SunlingPose.asleep
    @Environment(\.dismiss) private var dismiss

    /// He opens his eyes a little with each screen; on the last he's the icon, as the opening starts.
    private static let poses: [SunlingPose] = [.asleep, SunlingPose(rise: 0.87, leftLid: 594, rightLid: 584, lidLine: 1), .icon]

    var body: some View {
        GeometryReader { g in
            // The launch's horizon is the screen's middle line; Sunling sits above it, as the curtain draws him.
            let full = g.size.height + g.safeAreaInsets.top + g.safeAreaInsets.bottom
            let horizon = full / 2 - g.safeAreaInsets.top
            let bird = 250 * 1024 / 820.0 / SunlingLayer.aspect
            VStack(alignment: .leading, spacing: 0) {
                // Above him, the words; 24 pt under the horizon, what to choose.
                top
                    .frame(maxWidth: .infinity, maxHeight: max(0, horizon - bird - 24), alignment: .topLeading)
                Spacer(minLength: 0)
                    .frame(height: bird + 32)
                bottom
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .id(page)
            // One screen goes, then the next comes: the words never cross.
            .transition(.asymmetric(insertion: .opacity.animation(.easeOut(duration: 0.25).delay(0.18)),
                                    removal: .opacity.animation(.easeIn(duration: 0.18))))
        }
        .environment(\.colorScheme, .dark)
        .background {
            // Without the opening under it, the welcome draws the launch's night itself.
            if preview { WelcomeNight(pose: pose).animation(Motion.pick(Motion.sun, reduce: reduceMotion), value: pose) }
        }
        .onChange(of: page, initial: true) { _, p in
            if preview { pose = Self.poses[min(p, 2)] } else { opening.startPose = Self.poses[min(p, 2)] }
        }
        .onChange(of: cloud.linked) { _, linked in
            // "I already use Sunling": the cloud brings the rest.
            if linked { finish() }
        }
    }

    // MARK: The three screens

    @ViewBuilder
    private var top: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch page {
            case 0:
                title(String(localized: "Sunrise"))
                lead("Six short steps each morning, to start the day with yourself before the world. Sunling rises with each one.")
            case 1:
                title(String(localized: "When do you wake up?"))
                lead("Your sunrise starts when you wake up, not at 5.")
            default:
                title(String(localized: "Notifications"))
                lead("So you know when your reading minutes are up, even with the app closed, and once a month, to review your phrases.")
            }
        }
    }

    @ViewBuilder
    private var bottom: some View {
        switch page {
        case 0:
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Moment.allCases) { m in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(m.name)
                                .font(.display(20, relativeTo: .headline, weight: .bold))
                                .foregroundStyle(.ink)
                                .frame(minWidth: 84, alignment: .leading)
                            Text(AppLanguage.list(m.steps.map(\.name)))
                                .font(.reading(17))
                                .foregroundStyle(.muted)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Spacer(minLength: 16)
                next(String(localized: "Continue")) { go(1) }
                quiet(String(localized: "I already use Sunling")) {
                    if preview { finish() } else { Task { await cloud.signIn(using: webAuth) } }
                }
                .disabled(cloud.busy)
                if !cloud.error.isEmpty {
                    Text(cloud.error)
                        .font(.reading(15, relativeTo: .subheadline))
                        .foregroundStyle(.warn)
                        .frame(maxWidth: .infinity)
                }
            }
        case 1:
            VStack(alignment: .leading, spacing: 0) {
                TimeWheel(label: String(localized: "When you wake up"), time: wake) { wake = $0 }
                    .frame(maxWidth: .infinity, maxHeight: 132)
                    .clipped()
                Text("How long?")
                    .font(.reading(15, relativeTo: .subheadline).bold())
                    .foregroundStyle(.muted)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                SegmentedChoice(label: String(localized: "How long?"),
                                options: SunriseLength.allCases.map { .init(id: $0, title: $0.label, note: $0 == .ten ? String(localized: "to start") : nil) },
                                selection: $length)
                Text("Always the six steps: shorter, not fewer. You can change the minutes later.")
                    .font(.reading(15, relativeTo: .subheadline))
                    .foregroundStyle(.muted)
                    .padding(.top, 8)
                Spacer(minLength: 16)
                next(String(localized: "Continue")) {
                    if !preview { store.startFresh(wake: wake, length: length) }
                    go(2)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 0) {
                // What they look like: the two a new sunrise gets.
                VStack(spacing: 8) {
                    sample(String(localized: "Reading done"), String(localized: "You read for \(10) minutes. It checks itself off when you're back in Sunling."))
                    sample(String(localized: "Monthly review"), String(localized: "Do your affirmations and your Imagine questions still feel like yours?"))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Examples of notifications")
                Spacer(minLength: 16)
                next(String(localized: "Allow notifications")) {
                    asking = true
                    Task {
                        if !preview { await notices.askPermission() }
                        finish()
                    }
                }
                .disabled(asking)
                quiet(String(localized: "Not now")) { finish() }
                    .disabled(asking)
            }
        }
    }

    // MARK: Pieces

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.display(40, relativeTo: .largeTitle, weight: .heavy))
            .tracking(-0.5)
            .foregroundStyle(.ink)
            .minimumScaleFactor(0.6)
            .accessibilityAddTraits(.isHeader)
    }

    private func lead(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.reading(18, relativeTo: .body))
            .foregroundStyle(.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func next(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButton())
    }

    /// A notification as iOS shows it, with the icon's bird on its night.
    private func sample(_ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Like the icon: the bird wider than the square, on a horizon low in it.
            Sunling(pose: .icon)
                .frame(width: 44)
                .padding(.bottom, 9)
                .frame(width: 34, height: 34, alignment: .bottom)
                .background(Color.night)
                .clipShape(.rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(text).font(.system(size: 15)).lineLimit(2)
            }
            .foregroundStyle(.ink)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 22))
    }

    /// The second choice under the button: just words, with a whole row to tap.
    private func quiet(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.reading(16).bold())
                .foregroundStyle(.sky)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func go(_ p: Int) {
        withAnimation(reduceMotion ? Motion.fade : .easeInOut(duration: 0.4)) { page = p }
    }

    /// The night stays; the words go, and the curtain under them lands on Today.
    private func finish() {
        if preview { dismiss(); return }
        withAnimation(.easeOut(duration: 0.25)) { opening.welcoming = false }
    }
}

/// The launch's night for the welcome's preview: a horizon across the middle and Sunling on it, where the
/// opening curtain draws him.
private struct WelcomeNight: View {
    let pose: SunlingPose

    var body: some View {
        GeometryReader { g in
            let bird = OpeningCurtain.launchFrame(in: g.size)
            ZStack(alignment: .topLeading) {
                Color.night
                Color.horizon
                    .frame(width: g.size.width, height: 1.5)
                    .offset(y: g.size.height / 2 - 1.5)
                Sunling(pose: pose)
                    .frame(width: bird.width, height: bird.height)
                    .offset(x: bird.minX, y: bird.minY)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
