import SwiftUI
import MultipeerConnectivity

struct MenuBarView: View {
    @ObservedObject var appState: AppState

    @State private var showingPreferences = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status section
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(appState.connectionManager.connectionState.displayName)
                        .font(.headline)
                }

                if let peerName = appState.connectionManager.connectedPeerName {
                    Text(peerName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Removed packets/sec display to reduce UI updates
                // if appState.connectionManager.connectionState == .streaming {
                //     Text("\(Int(appState.motionProcessor.packetsPerSecond)) packets/sec")
                // }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Overlay toggle
            Button {
                appState.toggleOverlay()
            } label: {
                HStack {
                    Image(systemName: appState.overlayManager.isOverlayVisible ? "eye.fill" : "eye.slash")
                    Text(appState.overlayManager.isOverlayVisible ? "Hide Overlay" : "Show Overlay")
                    Spacer()
                    Text("⌘⇧M")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(MenuButtonStyle())

            Divider()

            // Connection controls
            if appState.connectionManager.connectionState == .disconnected {
                Button {
                    appState.connectionManager.startBrowsing()
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search for iPhone")
                    }
                }
                .buttonStyle(MenuButtonStyle())
            } else if appState.connectionManager.connectionState == .searching {
                Button {
                    appState.connectionManager.stopBrowsing()
                } label: {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Stop Searching")
                    }
                }
                .buttonStyle(MenuButtonStyle())

                // Show discovered peers
                if !appState.connectionManager.discoveredPeers.isEmpty {
                    Divider()
                    Text("Available Devices")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)

                    ForEach(appState.connectionManager.discoveredPeers, id: \.displayName) { peer in
                        Button {
                            appState.connectionManager.connect(to: peer)
                        } label: {
                            HStack {
                                Image(systemName: "iphone")
                                Text(peer.displayName)
                            }
                        }
                        .buttonStyle(MenuButtonStyle())
                    }
                }
            } else if appState.connectionManager.connectionState.isActive {
                Button {
                    appState.connectionManager.disconnect()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Disconnect")
                    }
                }
                .buttonStyle(MenuButtonStyle())
            }

            Divider()

            // Sensitivity presets
            Menu {
                Button("Low") {
                    appState.setSensitivityPreset(.low)
                }
                Button("Medium") {
                    appState.setSensitivityPreset(.medium)
                }
                Button("High") {
                    appState.setSensitivityPreset(.high)
                }
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("Sensitivity: \(appState.currentSensitivityPreset)")
                }
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Preferences
            Button {
                showingPreferences = true
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Preferences...")
                    Spacer()
                    Text("⌘,")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(MenuButtonStyle())

            Divider()

            // Quit
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Text("Quit RideSteady")
                    Spacer()
                    Text("⌘Q")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(MenuButtonStyle())
        }
        .frame(width: 240)
        .sheet(isPresented: $showingPreferences) {
            PreferencesWindow(appState: appState)
        }
    }

    private var statusColor: Color {
        switch appState.connectionManager.connectionState {
        case .disconnected: return .gray
        case .searching, .reconnecting: return .orange
        case .connecting: return .yellow
        case .connected: return .green
        case .streaming: return .blue
        }
    }
}

// MARK: - Menu Button Style

struct MenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(configuration.isPressed ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
    }
}
