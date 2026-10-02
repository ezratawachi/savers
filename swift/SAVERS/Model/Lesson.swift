import Foundation

/// What each step teaches: in its card the first time, and in Settings › The method.
extension Letter {
    /// What you do, in one line.
    var how: String {
        switch self {
        case .silencio: String(localized: "A few minutes still: breathe, meditate or pray.")
        case .afirmaciones: String(localized: "Out loud, a few phrases you believe about who you choose to be.")
        case .visualizacion: String(localized: "Today's most important thing, the obstacle most likely to get in the way, and what you'll do if it comes up.")
        case .ejercicio: String(localized: "A few minutes of movement at home, or your gym.")
        case .lectura: String(localized: "A few pages of something that helps you grow.")
        case .escritura: String(localized: "Give thanks for something specific, and jot down one idea from what you read.")
        }
    }

    /// Why, in plain words.
    var why: String {
        switch self {
        case .silencio: String(localized: "Starting without noise lowers stress and lets you choose how your day begins.")
        case .afirmaciones: String(localized: "Remembering your values steadies you. Over-the-top phrases can make you feel worse, so keep them believable.")
        case .visualizacion: String(localized: "Picturing the path, with an “if this happens, I'll do that” plan, helps you follow through more than picturing the goal alone.")
        case .ejercicio: String(localized: "Moving lifts your mood and your energy.")
        case .lectura: String(localized: "Learning a little every day adds up. The evidence here is weaker, and we say so.")
        case .escritura: String(localized: "Thanking something specific lifts your mood a little; writing down what you read helps you remember it.")
        }
    }

    /// The research behind the why; Read has none to point to.
    var sources: String? {
        switch self {
        case .silencio: "Goyal et al., 2014. JAMA Internal Medicine."
        case .afirmaciones: "Cohen & Sherman, 2014. Annual Review of Psychology · Wood, Perunovic & Lee, 2009. Psychological Science."
        case .visualizacion: "Kappes & Oettingen, 2011. JESP · Gollwitzer & Sheeran, 2006. Advances in Experimental Social Psychology."
        case .ejercicio: "Singh et al., 2023. British Journal of Sports Medicine."
        case .lectura: nil
        case .escritura: "Emmons & McCullough, 2003. JPSP · Roediger & Karpicke, 2006. Psychological Science."
        }
    }

    /// Its moment of the sunrise.
    var moment: Moment { Moment.allCases.first { $0.steps.contains(self) } ?? .grow }
}
