/// A block of the day's guide: "5:50 · SAVERS" and the letters it holds.
struct Block: Identifiable, Equatable {
    let id: String
    /// [hour, name] in the morning, ["Más tarde", hour] later; nil for the letters no block places.
    let head: [String]?
    let letters: [Letter]
    let isLater: Bool
}
