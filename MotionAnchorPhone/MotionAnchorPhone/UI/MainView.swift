import SwiftUI

struct MainView: View {
    @StateObject private var motionManager = MotionSensorManager()
    @StateObject private var peerManager = PeerAdvertiserManager()
    @State private var streamManager: StreamManager?

    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    // Status indicator
                    StatusIndicatorView(
                        connectionState: peerManager.connectionState,
                        connectedPeerName: peerManager.connectedPeerName,
                        isStreaming: streamManager?.isStreaming ?? false,
                        packetsPerSecond: streamManager?.packetsPerSecond ?? 0
                    )

                    Spacer()

                    // Main action button
                    MainActionButton(
                        connectionState: peerManager.connectionState,
                        isStreaming: streamManager?.isStreaming ?? false,
                        onTap: handleMainAction
                    )

                    // Calibrating indicator (banner)
                    if motionManager.isCalibrating {
                        CalibratingBannerView()
                    }

                    Spacer()

                    // Recalibrate button - quick inline recalibration
                    if peerManager.connectionState.isActive && motionManager.isCalibrated && !motionManager.isCalibrating {
                        Button("Recalibrate") {
                            quickRecalibrate()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }

                    // How it Works section
                    if peerManager.connectionState == .disconnected {
                        HowItWorksView()
                    }
                }
                .padding()
            }
            .navigationTitle("RideSteady")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(motionManager: motionManager)
            }
            .onAppear {
                setupStreamManager()
            }
        }
    }

    private func setupStreamManager() {
        if streamManager == nil {
            streamManager = StreamManager(
                motionManager: motionManager,
                peerManager: peerManager
            )
        }
    }

    private func quickRecalibrate() {
        // Background recalibration without interrupting streaming
        motionManager.calibrateInBackground()
    }

    private func handleMainAction() {
        switch peerManager.connectionState {
        case .disconnected:
            // Start advertising
            peerManager.startAdvertising()

        case .searching, .reconnecting:
            // Stop searching
            peerManager.stopAdvertising()

        case .connecting:
            // Wait...
            break

        case .connected, .streaming:
            if streamManager?.isStreaming == true {
                // Stop streaming
                streamManager?.stopStreaming()
            } else {
                // Start streaming - auto-calibrate in background if needed
                if !motionManager.isCalibrated {
                    // Start streaming first, then calibrate in background
                    streamManager?.startStreaming()
                    motionManager.calibrateInBackground()
                } else {
                    streamManager?.startStreaming()
                }
            }
        }
    }
}

// MARK: - Status Indicator

struct StatusIndicatorView: View {
    let connectionState: ConnectionState
    let connectedPeerName: String?
    let isStreaming: Bool
    let packetsPerSecond: Double

    @State private var linkPulse = false

    var body: some View {
        VStack(spacing: 20) {
            // Phone - Link - Computer visualization
            HStack(spacing: 0) {
                // iPhone
                VStack(spacing: 4) {
                    Image(systemName: "iphone")
                        .font(.system(size: 44))
                        .foregroundColor(isConnected ? .green : .gray)
                    Text("iPhone")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 70)

                // Connection link
                ZStack {
                    // Link line
                    Rectangle()
                        .fill(linkColor)
                        .frame(width: 80, height: 4)
                        .cornerRadius(2)

                    // Animated dots when streaming
                    if isStreaming {
                        HStack(spacing: 12) {
                            ForEach(0..<3) { i in
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                    .opacity(linkPulse ? 1.0 : 0.3)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(i) * 0.2),
                                        value: linkPulse
                                    )
                            }
                        }
                    }

                    // Link icon in center
                    Image(systemName: linkIcon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(linkIconColor)
                        .background(
                            Circle()
                                .fill(Color(UIColor.systemBackground))
                                .frame(width: 32, height: 32)
                        )
                }
                .frame(width: 100)

                // Mac
                VStack(spacing: 4) {
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 44))
                        .foregroundColor(isConnected ? .green : .gray)
                    Text(connectedPeerName ?? "Mac")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 70)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
            )

            // Status text
            VStack(spacing: 4) {
                Text(statusText)
                    .font(.headline)
                    .foregroundColor(statusTextColor)

                if isStreaming && packetsPerSecond > 0 {
                    Text("\(Int(packetsPerSecond)) packets/sec")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

                // Show hint when stuck at 0 packets
                if isStreaming && packetsPerSecond == 0 {
                    Text("Try stopping and restarting if this persists")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
            }
        }
        .onAppear {
            linkPulse = true
        }
    }

    private var isConnected: Bool {
        connectionState == .connected || connectionState == .streaming
    }

    private var linkColor: Color {
        switch connectionState {
        case .disconnected: return .gray.opacity(0.3)
        case .searching, .reconnecting: return .orange.opacity(0.5)
        case .connecting: return .yellow.opacity(0.5)
        case .connected, .streaming: return .green.opacity(0.5)
        }
    }

    private var linkIcon: String {
        switch connectionState {
        case .disconnected: return "link.badge.plus"
        case .searching: return "magnifyingglass"
        case .reconnecting: return "arrow.clockwise"
        case .connecting: return "ellipsis"
        case .connected, .streaming: return "link"
        }
    }

    private var linkIconColor: Color {
        switch connectionState {
        case .disconnected: return .gray
        case .searching, .reconnecting: return .orange
        case .connecting: return .yellow
        case .connected, .streaming: return .green
        }
    }

    private var statusText: String {
        switch connectionState {
        case .disconnected: return "Not Connected"
        case .searching: return "Searching for Mac..."
        case .reconnecting: return "Reconnecting..."
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .streaming:
            if packetsPerSecond > 0 {
                return "Connected"
            } else {
                return "Establishing connection..."
            }
        }
    }

    private var statusTextColor: Color {
        switch connectionState {
        case .disconnected: return .gray
        case .searching, .reconnecting: return .orange
        case .connecting: return .yellow
        case .connected: return .green
        case .streaming:
            return packetsPerSecond > 0 ? .green : .orange
        }
    }
}

// MARK: - Main Action Button

struct MainActionButton: View {
    let connectionState: ConnectionState
    let isStreaming: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: buttonIcon)
                    .font(.title2)
                Text(buttonTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(buttonColor)
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .padding(.horizontal, 32)
        .disabled(connectionState == .connecting)
    }

    private var buttonTitle: String {
        switch connectionState {
        case .disconnected:
            return "Start Streaming"
        case .searching:
            return "Stop Searching"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Begin Streaming"
        case .streaming:
            return isStreaming ? "Stop Streaming" : "Resume Streaming"
        case .reconnecting:
            return "Cancel"
        }
    }

    private var buttonIcon: String {
        switch connectionState {
        case .disconnected:
            return "play.fill"
        case .searching, .reconnecting:
            return "stop.fill"
        case .connecting:
            return "ellipsis"
        case .connected, .streaming:
            return isStreaming ? "stop.fill" : "play.fill"
        }
    }

    private var buttonColor: Color {
        switch connectionState {
        case .disconnected:
            return .blue
        case .searching, .reconnecting:
            return .orange
        case .connecting:
            return .gray
        case .connected:
            return .green
        case .streaming:
            return isStreaming ? .red : .blue
        }
    }
}

// MARK: - Phone Stability View

struct PhoneStabilityView: View {
    let isStable: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isStable ? Color.green : Color.orange)
                .frame(width: 8, height: 8)

            Text(isStable ? "Phone stable" : "Phone moving - data paused")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(20)
    }
}

// MARK: - Calibrating Banner View

struct CalibratingBannerView: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Calibrating...")
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.purple.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - How It Works View

struct HowItWorksView: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 12) {
            // Download Mac app reminder
            HStack(spacing: 8) {
                Image(systemName: "laptopcomputer")
                    .foregroundColor(.blue)
                Text("Download RideSteady on your Mac")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // How it works expandable
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    HowItWorksStep(number: 1, text: "Download RideSteady on your Mac from the App Store")
                    HowItWorksStep(number: 2, text: "Place your iPhone in a stable position in your vehicle")
                    HowItWorksStep(number: 3, text: "Tap \"Start Streaming\" on your iPhone")
                    HowItWorksStep(number: 4, text: "On your Mac, click \"Search for iPhone\" and connect")
                    HowItWorksStep(number: 5, text: "Visual anchors will appear on your Mac screen that move with your vehicle")

                    Text("The visual anchors help your brain reconcile what you see with what you feel, reducing motion sickness.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.blue)
                    Text("How it works")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct HowItWorksStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())

            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    MainView()
}
