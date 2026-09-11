import SwiftUI

/// The Sessions X star mark plus the app wordmark, used at the top of screens.
struct LogoHeader: View {
    var provider: SMSProvider? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image("LogoStars")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Theme.purple.opacity(0.55), lineWidth: 1.5)
                )
                .shadow(color: Theme.purple.opacity(0.55), radius: 18, x: 0, y: 0)

            VStack(spacing: 4) {
                Text("HeavenzySMS")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.accentGradient)
                if let provider = provider {
                    HStack(spacing: 6) {
                        Circle().fill(Theme.purpleBright).frame(width: 6, height: 6)
                        Text(provider.label)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.textSecondary)
                    }
                } else {
                    Text("Phone numbers & SMS codes")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}
