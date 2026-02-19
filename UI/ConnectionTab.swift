import SwiftUI
import MultipeerConnectivity

struct ConnectionTab: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Form {
            Section {
                // Connection status
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(appState.connectionManager.connectionState.displayName)
                        .fontWeight(.medium)

                    Spacer()

                    if let peerName = appState.connectionManager.connectedPeerName {
                        Text(peerName)
                            .foregroundColor(.secondary)
                    }
                }

                // Connection quality
                if appState.connectionManager.connectionState == .streaming {
                    HStack {
                        Text("Data Rate")
                        Spacer()
                        Text("\(Int(appState.motionProcessor.packetsPerSecond)) packets/sec")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
            } header: {
                Text("Status")
            }

            Section {
                // Discovered devices
                if appState.connectionManager.discoveredPeers.isEmpty {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Searching for devices...")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(appState.connectionManager.discoveredPeers, id: \.displayName) { peer in
                        HStack {
                            Image(systemName: "iphone")
                            Text(peer.displayName)

                            Spacer()

                            if appState.connectionManager.connectedPeerName == peer.displayName {
                                Text("Connected")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            } else {
                                Button("Connect") {
                                    appState.connectionManager.connect(to: peer)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            } header: {
                Text("Available Devices")
            }

            Section {
                // Control buttons
                HStack {
                    if appState.connectionManager.connectionState == .disconnected ||
                       appState.connectionManager.connectionState == .searching {
                        Button(appState.connectionManager.connectionState == .searching ? "Stop Searching" : "Search") {
                            if appState.connectionManager.connectionState == .searching {
                                appState.connectionManager.stopBrowsing()
                            } else {
                                appState.connectionManager.startBrowsing()
                            }
                        }
                    }

                    if appState.connectionManager.connectionState.isActive {
                        Button("Disconnect") {
                            appState.connectionManager.disconnect()
                        }
                        .foregroundColor(.red)
                    }
                }

                Toggle("Auto-connect to last device", isOn: $appState.autoConnectEnabled)
            } header: {
                Text("Actions")
            }

            // Error display
            if let error = appState.connectionManager.latestError {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                } header: {
                    Text("Error")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if appState.connectionManager.connectionState == .disconnected {
                appState.connectionManager.startBrowsing()
            }
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
