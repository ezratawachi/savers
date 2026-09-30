import CryptoKit
import Foundation
import Observation

/// A phrase ready to play: mono float samples at their own rate.
nonisolated struct VoiceClip: Sendable {
    var samples: [Float]
    var rate: Double
}

/// Gemini's voice: each phrase is made once and kept on this iPhone. The key lives only in the Keychain.
/// No key, no internet or no quota left: the iPhone's voice speaks instead, and only Ajustes › Voz says why.
@Observable
final class GeminiVoice {
    static let shared = GeminiVoice()

    struct Choice: Identifiable {
        var id: String
        var desc: String
    }

    static let voices = [
        Choice(id: "Sulafat", desc: "Mujer · cálida"),
        Choice(id: "Vindemiatrix", desc: "Mujer · suave"),
        Choice(id: "Achird", desc: "Hombre · amable"),
        Choice(id: "Algieba", desc: "Hombre · sereno"),
    ]

    static let model = "gemini-3.8-flash-tts"
    private static let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions")!

    // What Ajustes › Voz shows.
    private(set) var total = 0
    private(set) var ready = 0
    private(set) var nextReady = 0
    private(set) var error = ""
    private(set) var daily = false
    private(set) var key = Keychain.get("geminiKey") ?? ""
    private(set) var voice = ""
    /// The voice that was picked and is still being made; the current one keeps speaking until it's complete.
    private(set) var nextVoice = ""

    /// Everything the app can say today, with its tone. Set by the app.
    @ObservationIgnored var phrases: () -> [(String, SpeechTone)] = { [] }

    @ObservationIgnored private let prefs = LocalPrefs.standard
    @ObservationIgnored private var cache: [String: VoiceClip] = [:]
    @ObservationIgnored private var preparing = false
    @ObservationIgnored private var again = false
    @ObservationIgnored private var minuteHold = Date.distantPast
    @ObservationIgnored private var minuteMisses = 0
    @ObservationIgnored private var waitTask: Task<Void, Never>?

    private init() {
        voice = Self.known(prefs["voice"]) ?? Self.voices[0].id
        let next = Self.known(prefs["voiceNext"]) ?? ""
        nextVoice = next == voice ? "" : next
    }

    var hasKey: Bool { !key.isEmpty }

    private static func known(_ v: String?) -> String? { voices.contains { $0.id == v } ? v : nil }

    private var dailyHold: Date {
        Double(prefs["voiceHold"] ?? "").map { Date(timeIntervalSince1970: $0 / 1000) } ?? .distantPast
    }

    // MARK: Choosing

    func setKey(_ raw: String) {
        let k = raw.filter { !$0.isWhitespace }
        guard k != key else { return }
        key = k
        Keychain.set("geminiKey", k.isEmpty ? nil : k)
        error = ""
        total = 0
        clearHolds()
        cache = [:]
        prepare()
    }

    func choose(_ v: String) {
        let complete = total > 0 && ready == total
        // Until the current voice is complete there's nothing worth keeping on: switch right away.
        if v == voice || !complete {
            voice = v
            nextVoice = ""
            prefs["voice"] = v
            prefs["voiceNext"] = nil
            cache = [:]
        } else {
            nextVoice = v
            prefs["voiceNext"] = v
        }
        prepare()
    }

    // MARK: Speaking

    private static func clipKey(_ text: String, _ tone: SpeechTone, _ voice: String) -> String { "\(voice)|\(tone.id)|\(text)" }

    /// The clip of this phrase in the current voice, if it's on this iPhone.
    func clip(_ text: String, _ tone: SpeechTone) -> VoiceClip? {
        guard hasKey else { return nil }
        let k = Self.clipKey(text, tone, voice)
        if let c = cache[k] { return c }
        guard let data = try? Data(contentsOf: Self.file(k)), let c = Self.decodeWAV(data) else { return nil }
        cache[k] = c
        return c
    }

    /// "Probar" reads your first visualization question in that voice. Returns what went wrong, in plain words.
    func tryVoice(_ v: String) async -> String? {
        guard hasKey else { return "Primero pega tu clave de Gemini" }
        let text = phrases().first { $0.1 == .calm }?.0 ?? "Buenos días. Esta es tu voz para SAVERS."
        let k = Self.clipKey(text, .calm, v)
        do {
            if !FileManager.default.fileExists(atPath: Self.file(k).path) {
                try await make(text, .calm, v)
            }
            guard let data = try? Data(contentsOf: Self.file(k)), let clip = Self.decodeWAV(data) else { return "Gemini no respondió. Mientras, suena la voz del iPhone." }
            Voice.shared.stop()
            ToneEngine.shared.clip(clip)
            return nil
        } catch {
            let e = error as? TTSError
            if e?.status == 429 { note(e) }
            return message(e)
        }
    }

    // MARK: Making the phrases

    /// Makes whatever is missing, one phrase at a time, and forgets clips nothing says anymore.
    func prepare() {
        #if DEBUG
        // A scenario's made-up phrases don't go to Gemini or the real cache.
        if Scenario.current != nil { return }
        #endif
        if preparing { again = true; return }
        preparing = true
        Task {
            await makeAll()
            preparing = false
            if again { again = false; prepare() }
        }
    }

    private func makeAll() async {
        guard hasKey else { return }
        let list = dedup(phrases()), v = voice, next = nextVoice
        var ask = Date.now >= max(dailyHold, minuteHold)
        total = list.count
        ready = 0
        nextReady = 0
        daily = Date.now < dailyHold
        if ask { error = "" }
        // Staying open through the reset picks up what's missing.
        if daily { wait(until: dailyHold) }

        func pass(_ voice: String, count: (Int) -> Void) async {
            var n = 0
            for p in list {
                let k = Self.clipKey(p.0, p.1, voice)
                if FileManager.default.fileExists(atPath: Self.file(k).path) { n += 1; count(n); continue }
                guard ask else { continue }
                do {
                    try await make(p.0, p.1, voice)
                    n += 1
                    count(n)
                } catch {
                    ask = false
                    note(error as? TTSError)
                }
            }
        }
        // What the current voice is missing (a new visualization question) comes first.
        await pass(v) { ready = $0 }
        if !next.isEmpty { await pass(next) { nextReady = $0 } }

        // Keep every voice's clips of what the app says today, so going back to a voice costs nothing.
        var keep = Set<String>()
        for c in Self.voices { for p in list { keep.insert(Self.file(Self.clipKey(p.0, p.1, c.id)).lastPathComponent) } }
        let dir = Self.dir
        for name in (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [] where !keep.contains(name) {
            try? FileManager.default.removeItem(at: dir.appending(path: name))
        }
        if !next.isEmpty && nextReady == list.count && next == nextVoice {
            voice = next
            nextVoice = ""
            prefs["voice"] = next
            prefs["voiceNext"] = nil
            cache = [:]
            again = true
        }
    }

    private func dedup(_ list: [(String, SpeechTone)]) -> [(String, SpeechTone)] {
        var seen = Set<String>()
        return list.filter { !$0.0.isEmpty && seen.insert($0.1.id + "|" + $0.0).inserted }
    }

    private func make(_ text: String, _ tone: SpeechTone, _ voice: String) async throws {
        let wav = try await synth(text, tone, voice)
        clearHolds()
        try FileManager.default.createDirectory(at: Self.dir, withIntermediateDirectories: true)
        try wav.write(to: Self.file(Self.clipKey(text, tone, voice)), options: .atomic)
    }

    // MARK: Quota

    private func clearHolds() {
        prefs["voiceHold"] = nil
        minuteHold = .distantPast
        minuteMisses = 0
    }

    /// A full day's quota waits for its reset; a busy minute tries again in a minute (three in a row count as the day).
    private func note(_ e: TTSError?) {
        // Google busy for a moment (500, 503): try again soon, without a word about it.
        if let e, let s = e.status, s >= 500 {
            minuteHold = .now.addingTimeInterval(30)
            wait(until: minuteHold)
            error = ""
            return
        }
        guard let e, e.status == 429 else {
            error = message(e)
            return
        }
        minuteMisses += 1
        if e.daily || minuteMisses >= 3 {
            let reset = Self.nextQuotaReset()
            prefs["voiceHold"] = String(reset.timeIntervalSince1970 * 1000)
            daily = true
            wait(until: reset)
        } else {
            minuteHold = .now.addingTimeInterval(max(e.retry, 60))
            wait(until: minuteHold)
        }
        error = ""
    }

    private func wait(until date: Date) {
        waitTask?.cancel()
        waitTask = Task {
            try? await Task.sleep(for: .seconds(max(0, date.timeIntervalSinceNow) + 1))
            guard !Task.isCancelled else { return }
            prepare()
        }
    }

    /// The daily quota comes back at midnight, Pacific time.
    private static func nextQuotaReset() -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let midnight = cal.nextDate(after: .now, matching: DateComponents(hour: 0), matchingPolicy: .nextTime) ?? .now.addingTimeInterval(86_400)
        return midnight.addingTimeInterval(60)
    }

    func message(_ e: TTSError?) -> String {
        guard let e, !e.offline else { return "Sin conexión. Prueba cuando tengas internet." }
        if e.status == 429 && (e.daily || Date.now < dailyHold) { return "Ya se usó el límite gratis de hoy. Mañana puedes probar más voces." }
        if e.status == 429 { return "Google pide una pausa. Espera un minuto y vuelve a probar." }
        if e.status == 401 || e.status == 403 || e.reason.contains("API_KEY") { return "La clave no funciona. Revisa que esté completa." }
        return "Gemini no respondió" + (e.status.map { " (código \($0))" } ?? "") + ". Mientras, suena la voz del iPhone."
    }

    var statusText: String {
        guard hasKey else { return "Sin clave, suena la voz del iPhone." }
        if !error.isEmpty { return error }
        let n = total
        guard n > 0 else { return "Preparando las frases…" }
        var t = !nextVoice.isEmpty ? "\(nextVoice) se está preparando: \(nextReady) de \(n) frases. Mientras, suena \(voice)."
            : ready == n ? "Las \(n) frases están listas en este iPhone."
            : "\(ready) de \(n) frases listas. Las que faltan suenan con la voz del iPhone."
        if daily && (!nextVoice.isEmpty || ready < n) { t += " Se acabó el límite gratis de hoy: mañana se completan." }
        return t
    }

    var statusIsWarning: Bool { hasKey && (!error.isEmpty || (daily && (!nextVoice.isEmpty || ready < total))) }

    // MARK: Files

    private static let dir = URL.applicationSupportDirectory.appending(path: "savers/voz", directoryHint: .isDirectory)

    /// The same name as the web: the first 16 bytes of SHA-256("model|voice|tone|text"), in hex.
    private static func file(_ key: String) -> URL {
        let hash = SHA256.hash(data: Data((model + "|" + key).utf8))
        let hex = hash.prefix(16).map { String(format: "%02x", $0) }.joined()
        return dir.appending(path: hex + ".wav")
    }

    // MARK: Gemini

    struct TTSError: Error {
        var status: Int?
        var reason = ""
        /// Seconds Google asks to wait.
        var retry = 0.0
        var daily = false
        var offline = false
    }

    private func synth(_ text: String, _ tone: SpeechTone, _ voice: String) async throws -> Data {
        var req = URLRequest(url: Self.url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        let body: [String: Any] = [
            "model": Self.model,
            "input": [["type": "user_input", "content": [["type": "text", "text": text, "annotations": [["type": "speech_metadata", "style": tone.style]]]]]],
            "response_format": ["type": "audio"],
            "generation_config": ["speech_config": [["voice": voice]]],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data: Data, res: URLResponse
        do { (data, res) = try await URLSession.shared.data(for: req) } catch { throw TTSError(offline: true) }
        let status = (res as? HTTPURLResponse)?.statusCode ?? 0
        let json = try? JSONSerialization.jsonObject(with: data)
        guard (200..<300).contains(status) else {
            let top = (json as? [Any])?.first ?? json
            let info = (top as? [String: Any])?["error"] as? [String: Any] ?? [:]
            let details = info["details"] as? [[String: Any]] ?? []
            let retry = details.compactMap { $0["retryDelay"] as? String }.first.flatMap { Double($0.trimmingCharacters(in: CharacterSet(charactersIn: "s"))) } ?? 0
            let raw = (try? JSONSerialization.data(withJSONObject: details)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
            throw TTSError(status: status, reason: details.compactMap { $0["reason"] as? String }.joined(separator: " "),
                           retry: retry, daily: raw.range(of: "PerDay", options: .caseInsensitive) != nil)
        }
        guard let b64 = Self.audio(in: json), let bytes = Data(base64Encoded: b64) else { throw TTSError(status: status, reason: "Sin audio") }
        return Self.asWAV(bytes)
    }

    private static func audio(in json: Any?) -> String? {
        guard let obj = json as? [String: Any] else { return nil }
        if let out = obj["output_audio"] as? [String: Any], let d = out["data"] as? String { return d }
        var found: String?
        for step in obj["steps"] as? [[String: Any]] ?? [] {
            for c in step["content"] as? [[String: Any]] ?? [] where c["type"] as? String == "audio" {
                if let d = c["data"] as? String { found = d }
            }
        }
        return found
    }

    /// Gemini answers with a WAV, or raw 16-bit PCM (24 kHz mono) that gets a header.
    private static func asWAV(_ pcm: Data) -> Data {
        if pcm.count > 12 && pcm.prefix(4) == Data("RIFF".utf8) { return pcm }
        let rate: UInt32 = 24_000
        var out = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { out.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { out.append(contentsOf: $0) } }
        out.append(Data("RIFF".utf8)); u32(36 + UInt32(pcm.count)); out.append(Data("WAVEfmt ".utf8))
        u32(16); u16(1); u16(1); u32(rate); u32(rate * 2); u16(2); u16(16)
        out.append(Data("data".utf8)); u32(UInt32(pcm.count))
        out.append(pcm)
        return out
    }

    /// 16-bit PCM WAV → mono float.
    private static func decodeWAV(_ d: Data) -> VoiceClip? {
        let b = [UInt8](d)
        guard b.count > 44, String(decoding: b[0..<4], as: UTF8.self) == "RIFF" else { return nil }
        func u16(_ i: Int) -> Int { Int(b[i]) | Int(b[i + 1]) << 8 }
        func u32(_ i: Int) -> Int { u16(i) | u16(i + 2) << 16 }
        var i = 12, rate = 24_000, channels = 1, bits = 16
        while i + 8 <= b.count {
            let id = String(decoding: b[i..<i + 4], as: UTF8.self), size = u32(i + 4)
            if id == "fmt " {
                channels = max(1, u16(i + 10))
                rate = u32(i + 12)
                bits = u16(i + 22)
            } else if id == "data" {
                guard bits == 16 else { return nil }
                let end = min(b.count, i + 8 + size), frame = 2 * channels
                var samples = [Float]()
                samples.reserveCapacity((end - i - 8) / frame)
                var j = i + 8
                while j + 1 < end {
                    samples.append(Float(Int16(bitPattern: UInt16(u16(j)))) / 32_768)
                    j += frame
                }
                return VoiceClip(samples: samples, rate: Double(rate))
            }
            i += 8 + size + size % 2
        }
        return nil
    }
}
