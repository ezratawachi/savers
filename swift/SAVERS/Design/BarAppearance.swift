import SwiftUI

/// The bars in the app's colors: titles in Bricolage and ink, like the date on Hoy, and the tab bar and a
/// scrolled navigation bar tinted with the background (the system's gray shows up against the night blue).
/// SwiftUI has no modifier for a title's font or a tinted material, so this is set once for every bar.
enum BarAppearance {
    static func apply() {
        let ink = UIColor(named: "Ink") ?? .label
        let tint = (UIColor(named: "Bg") ?? .systemBackground).withAlphaComponent(0.82)

        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.backgroundColor = tint
        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        for a in [scrolled, edge] {
            a.largeTitleTextAttributes = [.font: font(34, .largeTitle), .foregroundColor: ink]
            a.titleTextAttributes = [.font: font(18, .headline, weight: .bold), .foregroundColor: ink]
        }
        let nav = UINavigationBar.appearance()
        nav.standardAppearance = scrolled
        nav.compactAppearance = scrolled
        nav.scrollEdgeAppearance = edge

        let tabs = UITabBarAppearance()
        tabs.configureWithDefaultBackground()
        tabs.backgroundColor = tint
        UITabBar.appearance().standardAppearance = tabs
        UITabBar.appearance().scrollEdgeAppearance = tabs
    }

    private static func font(_ size: CGFloat, _ style: UIFont.TextStyle, weight: UIFont.Weight = .heavy) -> UIFont {
        let descriptor = UIFontDescriptor(fontAttributes: [.family: "Bricolage Grotesque"])
            .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: size))
    }
}
