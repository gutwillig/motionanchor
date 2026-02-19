import SwiftUI

struct PreferencesWindow: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ConnectionTab(appState: appState)
                .tabItem {
                    Label("Connection", systemImage: "wifi")
                }
                .tag(0)

            AppearanceTab(appState: appState)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(1)

            MotionTab(appState: appState)
                .tabItem {
                    Label("Motion", systemImage: "waveform.path")
                }
                .tag(2)

            GeneralTab(appState: appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(3)
        }
        .frame(width: 500, height: 400)
        .onExitCommand {
            dismiss()
        }
    }
}

#Preview {
    PreferencesWindow(appState: AppState())
}
