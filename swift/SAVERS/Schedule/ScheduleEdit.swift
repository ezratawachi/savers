/// What a kind's page opens in a sheet: a block, a step's minutes, or the wind-down.
enum ScheduleEdit: Identifiable {
    case step(DayType, String)
    case minutes(DayType, Letter)
    case windDown

    var id: String {
        switch self {
        case .step(let k, let id): "\(k.id)-\(id)"
        case .minutes(let k, let l): "\(k.id)-\(l.rawValue)"
        case .windDown: "windDown"
        }
    }

    /// A block's sheet has more under its wheel: its name, its steps.
    var isStep: Bool {
        if case .step = self { true } else { false }
    }
}
