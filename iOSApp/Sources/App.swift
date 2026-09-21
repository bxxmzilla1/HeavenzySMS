import SwiftUI

@main
struct HeavenzySMSApp: App {
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TabView {
            NumberView()
                .tabItem { Label("Numbers", systemImage: "phone.arrow.down.left.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Theme.accentBright)
        .onAppear { KeyboardDismissInstaller.shared.install() }
    }
}
