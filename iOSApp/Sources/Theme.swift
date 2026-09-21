import SwiftUI

/// Visual language for HeavenzySMS — a dark, high-end look built around the
/// neon-emerald star mark. Colors are sampled from the logo itself.
enum Theme {
    static let accent = Color(red: 0.173, green: 0.804, blue: 0.435)       // #2CCD6F ring green
    static let accentBright = Color(red: 0.455, green: 1.000, blue: 0.737) // #74FFBC star highlight
    static let accentDeep = Color(red: 0.043, green: 0.420, blue: 0.227)   // #0B6B3A shadow green

    static let bg = Color(red: 0.008, green: 0.039, blue: 0.020)           // #020A05 logo background
    static let bg2 = Color(red: 0.016, green: 0.086, blue: 0.047)          // #04160C
    static let card = Color.white.opacity(0.05)
    static let cardStroke = accent.opacity(0.14)
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
            colors: [accentBright, accent, accentDeep],
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

/// Primary call-to-action button style with the signature emerald gradient.
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
            .shadow(color: Theme.accent.opacity(enabled ? 0.5 : 0), radius: 16, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
