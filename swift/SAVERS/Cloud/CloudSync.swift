import SwiftUI
import AuthenticationServices
import Foundation
import Observation
import UIKit

/// Settings and days also live in Firestore, so the Mac's web sees and edits the same thing.
/// This iPhone stays the source of truth: nothing waits for the network. Every save goes up, and while the app
/// is open it asks every 15 s for what the Mac changed. The newest `updatedAt` wins, like an import.
@Observable
final class CloudSync {
    /// Signed in on this iPhone (even before the first answer).
    private(set) var linked: Bool
    /// The first download is in, so saves can go up without overwriting the cloud.
    private(set) var ready = false
    private(set) var busy = false
    private(set) var offline = false
    private(set) var error = ""
    private(set) var email: String?
    private(set) var lastAt: Date?

    @ObservationIgnored private let store: AppStore
    @ObservationIgnored private let prefs: LocalPrefs
    @ObservationIgnored private var session: Firebase.Session?
    /// Date -> the `updatedAt` the cloud already has.
    @ObservationIgnored private var pushed: [String: String]
    @ObservationIgnored private var pushing = false
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var pushTask: Task<Void, Never>?

    private static let refreshKey = "cloudRefresh"

    init(store: AppStore, prefs: LocalPrefs = .standard) {
        self.store = store
        self.prefs = prefs
        linked = prefs["cloudUid"] != nil && Keychain.get(Self.refreshKey) != nil
        email = prefs["cloudEmail"]
        lastAt = Date(iso: prefs["cloudAt"])
        pushed = prefs["cloudPushed"].flatMap { try? JSONDecoder().decode([String: String].self, from: Data($0.utf8)) } ?? [:]
        store.onSave = { [weak self] in self?.pushSoon() }
    }

    // MARK: Signing in and out

    func signIn(using web: WebAuthenticationSession) async {
        busy = true
        error = ""
        defer { busy = false }
        do {
            let google = try await GoogleSignIn.idToken(using: web)
            let s = try await Firebase.signIn(googleIdToken: google)
            session = s
            Keychain.set(Self.refreshKey, s.refreshToken)
            prefs["cloudEmail"] = s.email
            email = s.email
            ready = false
            linked = true
            loop?.cancel()
            loop = Task { await run() }
        } catch CloudError.cancelled {
        } catch CloudError.offline {
            error = String(localized: "No connection: try again later.")
        } catch {
            self.error = String(localized: "Couldn't sign in with Google. Tap again.")
        }
    }

    /// The data stays on this iPhone; it just stops going to the cloud.
    func signOut(message: String = "") {
        loop?.cancel()
        loop = nil
        session = nil
        Keychain.set(Self.refreshKey, nil)
        prefs["cloudUid"] = nil
        linked = false
        ready = false
        error = message
    }

    // MARK: While the app is open

    func resume() {
        guard linked, loop == nil else { return }
        loop = Task { await run() }
    }

    /// Going to the background: stop asking, but send what's left right away.
    func pause() {
        loop?.cancel()
        loop = nil
        pushTask?.cancel()
        pushTask = Task { await push() }
    }

    private func run() async {
        while !Task.isCancelled && linked {
            await sync()
            try? await Task.sleep(for: .seconds(15))
        }
    }

    /// Brings down what changed, then sends up what this iPhone changed.
    private func sync() async {
        do {
            let token = try await idToken()
            guard let uid = session?.uid else { return }
            // First time on this iPhone with this account: whatever the cloud has wins over the local settings.
            let firstLink = !ready && prefs["cloudLastUid"] != uid
            if firstLink {
                pushed = [:]
                prefs["cloudSeen"] = nil
            }
            if let doc = try await Firebase.document("users/\(uid)/meta/settings", token: token) {
                store.applyCloudSettings(doc, force: firstLink)
            }
            // Only days written since the last look come down: a few reads per open, not the whole history.
            let seen = Double(prefs["cloudSeen"] ?? "") ?? 0
            let rows = try await Firebase.days(uid: uid, since: Date(timeIntervalSince1970: seen / 1000), token: token)
            var maxSeen = seen
            var incoming: [String: JSONValue] = [:]
            for row in rows {
                if let at = row.syncedAt { maxSeen = max(maxSeen, (at.timeIntervalSince1970 * 1000).rounded(.down)) }
                if let day = row.fields["day"] { incoming[row.id] = day }
            }
            for (ds, at) in store.applyCloudDays(incoming, unsent: unsentDates) { pushed[ds] = at }
            savePushed()
            prefs["cloudSeen"] = String(Int(maxSeen))
            if !ready {
                ready = true
                prefs["cloudUid"] = uid
                prefs["cloudLastUid"] = uid
                touch()
            }
            offline = false
            error = ""
            await push()
        } catch {
            handle(error)
        }
    }

    // MARK: Sending

    private func pushSoon() {
        guard ready else { return }
        pushTask?.cancel()
        pushTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await push()
        }
    }

    /// Days changed here that the cloud doesn't have yet.
    private var unsentDates: Set<String> {
        Set(store.days.compactMap { ds, d in pushed[ds] == (d.updatedAt ?? "") ? nil : ds })
    }

    private var settingsAt: String { prefs["settingsAt"] ?? "" }

    var pending: Bool { prefs["settingsPushed"] != settingsAt || !unsentDates.isEmpty }

    private func push() async {
        guard ready, !pushing, linked else { return }
        pushing = true
        // A few seconds to finish if the app goes to the background right after a change.
        let bg = UIApplication.shared.beginBackgroundTask(withName: "savers-nube")
        defer {
            pushing = false
            UIApplication.shared.endBackgroundTask(bg)
        }
        do {
            let token = try await idToken()
            guard let uid = session?.uid else { return }
            var docs: [(path: String, fields: [String: JSONValue])] = []
            var sent: [String: String] = [:]
            for ds in unsentDates.sorted() {
                guard let d = store.days[ds] else { continue }
                docs.append(("users/\(uid)/days/\(ds)", ["day": JSONValue(d)]))
                sent[ds] = d.updatedAt ?? ""
            }
            let sAt = settingsAt
            let settingsDue = prefs["settingsPushed"] != sAt
            if settingsDue {
                docs.append(("users/\(uid)/meta/settings", ["settings": JSONValue(store.settings), "updatedAt": .string(sAt)]))
            }
            guard !docs.isEmpty else { return }
            for start in stride(from: 0, to: docs.count, by: 400) {
                try await Firebase.write(Array(docs[start..<min(start + 400, docs.count)]), token: token)
            }
            for (ds, at) in sent { pushed[ds] = at }
            savePushed()
            if settingsDue { prefs["settingsPushed"] = sAt }
            touch()
            offline = false
        } catch {
            handle(error)
        }
    }

    // MARK: Helpers

    private func idToken() async throws -> String {
        if let s = session, s.expires > .now { return s.idToken }
        guard let refresh = Keychain.get(Self.refreshKey) else { throw CloudError.signedOut }
        var s = try await Firebase.refresh(refresh)
        s.email = email
        session = s
        if s.refreshToken != refresh { Keychain.set(Self.refreshKey, s.refreshToken) }
        return s.idToken
    }

    private func handle(_ e: Error) {
        switch e as? CloudError {
        case .offline: offline = true
        case .unauthorized: session = nil
        case .denied: signOut(message: String(localized: "This Google account doesn't have access to this app."))
        case .signedOut: signOut()
        default: error = String(localized: "Couldn't connect to the cloud.")
        }
    }

    private func savePushed() {
        prefs["cloudPushed"] = (try? JSONEncoder().encode(pushed)).flatMap { String(data: $0, encoding: .utf8) }
    }

    private func touch() {
        lastAt = .now
        prefs["cloudAt"] = Date.now.iso
    }

    /// "Saved · 5 min ago", like the web.
    func statusLabel(now: Date = .now) -> String {
        guard linked else { return "" }
        if !error.isEmpty { return error }
        if !ready || pending {
            return offline ? String(localized: "Offline · it uploads later") : ready ? String(localized: "Uploading…") : String(localized: "Connecting…")
        }
        guard let lastAt else { return String(localized: "Saved") }
        let min = Int(now.timeIntervalSince(lastAt) / 60)
        let ago = min < 1 ? String(localized: "just now")
            : min < 60 ? String(localized: "\(min) min ago")
            : min < 1440 ? String(localized: "\(min / 60) h ago")
            : String(localized: "\(min / 1440) days ago")
        return String(localized: "Saved · \(ago)")
    }
}

extension JSONValue {
    /// Any Codable value as plain JSON (the way it's saved on this iPhone).
    init<T: Encodable>(_ value: T) {
        self = (try? Persistence.encoder.encode(value)).flatMap { try? JSONDecoder().decode(JSONValue.self, from: $0) } ?? .null
    }
}
