/// Where a step goes when it isn't in the sunrise: its block and that block's hour on the date.
struct Placement {
    let step: Step
    /// "5:15", "8:50 pm"; empty when the block has no hour.
    let time: String
    /// In "Más tarde".
    let isLater: Bool
    /// After the sunrise, in the morning or later: it gets its own "it's time" notice.
    let afterSunrise: Bool
}
