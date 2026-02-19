import SwiftUI
import ServiceManagement

struct GeneralTab: View {
    @ObservedObject var appState: AppState

    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showDockIcon") private var showDockIcon = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }

                Toggle("Show in Dock", isOn: $showDockIcon)
                    .onChange(of: showDockIcon) { _, newValue in
                        setDockIconVisibility(newValue)
                    }

                Text("When disabled, MotionAnchor runs as a menu bar app only.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Startup")
            }

            Section {
                HStack {
                    Text("Toggle Overlay")
                    Spacer()
                    Text("⌘⇧M")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }

                HStack {
                    Text("Open Preferences")
                    Spacer()
                    Text("⌘,")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }

                HStack {
                    Text("Quit")
                    Spacer()
                    Text("⌘Q")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            } header: {
                Text("Keyboard Shortcuts")
            }

            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("macOS")
                    Spacer()
                    Text(ProcessInfo.processInfo.operatingSystemVersionString)
                        .foregroundColor(.secondary)
                }

                Button("Check for Updates...") {
                    // TODO: Implement update checking
                }
            } header: {
                Text("About")
            }

            Section {
                Button("Reset All Settings") {
                    resetAllSettings()
                }
                .foregroundColor(.red)
            } header: {
                Text("Reset")
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }

    private func setDockIconVisibility(_ show: Bool) {
        if show {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func resetAllSettings() {
        // Reset all UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        // Reset processor settings
        appState.motionProcessor.sensitivityMultiplier = 1.0
        appState.motionProcessor.smoothingAlpha = 0.3
        appState.motionProcessor.maxDisplacement = 150
        appState.motionProcessor.lateralGain = 300
        appState.motionProcessor.longitudinalGain = 200
        appState.motionProcessor.verticalGain = 100
        appState.motionProcessor.yawGain = 50

        // Reset particle renderer settings
        appState.dotRenderer.particleCount = 40
        appState.dotRenderer.particleSize = 7
        appState.dotRenderer.maxOpacity = 0.6
        appState.dotRenderer.particleColor = .white
    }
}
