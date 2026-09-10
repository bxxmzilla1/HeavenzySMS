import SwiftUI

/// Visual language for HeavenzySMS — a dark, high-end look built around the
/// purple-star Sessions X mark.
enum Theme {
    static let purple = Color(red: 0.545, green: 0.184, blue: 0.878)   // #8B2FE0
    static let purpleBright = Color(red: 0.667, green: 0.361, blue: 0.988) // #AA5CFC
    static let purpleDeep = Color(red: 0.298, green: 0.086, blue: 0.529) // #4C1687

    static let bg = Color(red: 0.039, green: 0.031, blue: 0.063)       // near-black indigo
    static let bg2 = Color(red: 0.071, green: 0.055, blue: 0.114)
    static let card = Color.white.opacity(0.05)
    static let cardStroke = Color.white.opacity(0.09)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [bg2, bg, Color.black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [purpleBright, purple, purpleDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// A frosted card surface used throughout the app.
struct GlassCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
    }
}

/// Primary call-to-action button style with the signature purple gradient.
struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.accentGradient)
                    .opacity(enabled ? 1 : 0.35)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Theme.purple.opacity(enabled ? 0.5 : 0), radius: 16, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
