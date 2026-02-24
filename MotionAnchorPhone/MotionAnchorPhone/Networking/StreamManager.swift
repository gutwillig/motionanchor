import Foundation
import Combine

/// Coordinates motion data streaming from sensor to network
final class StreamManager: ObservableObject {

    // MARK: - Published Properties

    @Published var isStreaming = false
    @Published var packetsPerSecond: Double = 0
    @Published var averageLatency: Double = 0

    // MARK: - Dependencies

    private let motionManager: MotionSensorManager
    private let peerManager: PeerAdvertiserManager

    // MARK: - Private Properties

    private var packetCount = 0
    private var packetCountTimer: Timer?
    private var lastPacketCountReset = Date()

    // MARK: - Initialization

    init(motionManager: MotionSensorManager, peerManager: PeerAdvertiserManager) {
        self.motionManager = motionManager
        self.peerManager = peerManager

        setupMotionCallback()
    }

    // MARK: - Public Methods

    /// Start streaming motion data to connected Mac
    func startStreaming() {
        guard peerManager.connectionState.isActive else {
            print("Cannot start streaming - not connected")
            return
        }

        motionManager.startMotionUpdates()
        startPacketCounter()

        DispatchQueue.main.async {
            self.isStreaming = true
        }
    }

    /// Stop streaming motion data
    func stopStreaming() {
        motionManager.stopMotionUpdates()
        stopPacketCounter()

        DispatchQueue.main.async {
            self.isStreaming = false
            self.packetsPerSecond = 0
        }
    }

    /// Calibrate the phone's orientation
    func calibrate() {
        motionManager.calibrate()
    }

    // MARK: - Private Methods

    private func setupMotionCallback() {
        motionManager.onMotionPacket = { [weak self] packet in
            self?.handleMotionPacket(packet)
        }
    }

    private func handleMotionPacket(_ packet: MotionPacket) {
        // Send to connected Mac (always send - phone will be moving in vehicle)
        peerManager.sendMotionPacket(packet)

        // Update packet counter
        packetCount += 1
    }

    private func startPacketCounter() {
        packetCount = 0
        lastPacketCountReset = Date()

        packetCountTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let elapsed = Date().timeIntervalSince(self.lastPacketCountReset)
            let rate = Double(self.packetCount) / elapsed

            DispatchQueue.main.async {
                self.packetsPerSecond = rate
            }

            self.packetCount = 0
            self.lastPacketCountReset = Date()
        }
    }

    private func stopPacketCounter() {
        packetCountTimer?.invalidate()
        packetCountTimer = nil
    }
}
