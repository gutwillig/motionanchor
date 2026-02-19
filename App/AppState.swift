import SwiftUI
import Combine

/// Central state management for the Mac app
final class AppState: ObservableObject {

    // MARK: - Published State

    @Published var currentSensitivityPreset: String = "Medium"
    @Published var autoConnectEnabled: Bool = true

    // MARK: - Components

    let connectionManager = PeerConnectionManager()
    let motionProcessor = MotionDataProcessor()
    let dotRenderer = DotRenderer()
    let overlayManager = OverlayWindowManager()

    private let simulatedMotion = SimulatedMotion()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupBindings()
        loadSettings()

        // Auto-show overlay on launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.overlayManager.showOverlay()
        }
    }

    // MARK: - Setup

    private var packetCount = 0

    private func setupBindings() {
        // Connect dotRenderer to overlayManager so dots can be drawn
        overlayManager.setDotRenderer(dotRenderer)

        // SIMPLIFIED: Direct motion to dots, skip MotionDataProcessor
        connectionManager.onMotionPacketReceived = { [weak self] packet in
            guard let self = self else { return }
            self.packetCount += 1

            // Direct mapping: acceleration -> dot offset (simple multiplier)
            let gain: CGFloat = 200  // pixels per g-force
            let offsetX = CGFloat(-packet.userAcceleration.x) * gain
            let offsetY = CGFloat(-packet.userAcceleration.y) * gain

            // Clamp to reasonable range
            let maxOffset: CGFloat = 100
            self.dotRenderer.currentOffset = CGPoint(
                x: max(-maxOffset, min(maxOffset, offsetX)),
                y: max(-maxOffset, min(maxOffset, offsetY))
            )

            // Log occasionally
            if self.packetCount % 100 == 0 {
                print("📦 Packets: \(self.packetCount)")
            }
        }

        // Handle connection state changes
        connectionManager.onConnectionStateChanged = { state in
            print("Connection state: \(state)")
        }
    }

    private func loadSettings() {
        // Load saved settings from UserDefaults
        if let preset = UserDefaults.standard.string(forKey: "sensitivityPreset") {
            currentSensitivityPreset = preset
            applySensitivityPreset(preset)
        }

        autoConnectEnabled = UserDefaults.standard.bool(forKey: "autoConnectEnabled")

        // DISABLED: Auto-connect causes freezing issues, debug first
        // if autoConnectEnabled {
        //     DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
        //         self?.connectionManager.autoConnect()
        //     }
        // }
    }

    // MARK: - Public Methods

    /// Toggle overlay visibility
    func toggleOverlay() {
        print("DEBUG: toggleOverlay called")
        overlayManager.toggleOverlay()
    }

    /// Set sensitivity preset
    func setSensitivityPreset(_ preset: SensitivityPreset) {
        switch preset {
        case .low:
            currentSensitivityPreset = "Low"
            applySensitivityPreset("Low")
        case .medium:
            currentSensitivityPreset = "Medium"
            applySensitivityPreset("Medium")
        case .high:
            currentSensitivityPreset = "High"
            applySensitivityPreset("High")
        }

        UserDefaults.standard.set(currentSensitivityPreset, forKey: "sensitivityPreset")
    }

    /// Start test mode with simulated motion
    func startTestMode() {
        // Show overlay if not visible
        if !overlayManager.isOverlayVisible {
            overlayManager.showOverlay()
        }

        simulatedMotion.mode = .gentleDriving
        simulatedMotion.start()
    }

    /// Stop test mode
    func stopTestMode() {
        simulatedMotion.stop()
        dotRenderer.startReturnToHome()
    }

    // MARK: - Private Methods

    private func applySensitivityPreset(_ preset: String) {
        switch preset {
        case "Low":
            motionProcessor.sensitivityMultiplier = 0.5
            motionProcessor.lateralGain = 150
            motionProcessor.longitudinalGain = 100
            motionProcessor.maxDisplacement = 100

        case "High":
            motionProcessor.sensitivityMultiplier = 1.5
            motionProcessor.lateralGain = 450
            motionProcessor.longitudinalGain = 300
            motionProcessor.maxDisplacement = 200

        default: // Medium
            motionProcessor.sensitivityMultiplier = 1.0
            motionProcessor.lateralGain = 300
            motionProcessor.longitudinalGain = 200
            motionProcessor.maxDisplacement = 150
        }
    }

    enum SensitivityPreset {
        case low, medium, high
    }
}
