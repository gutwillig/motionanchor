import Foundation
import Combine

/// Processes incoming motion data from iPhone and prepares it for dot rendering
final class MotionDataProcessor: ObservableObject {

    // MARK: - Published State

    @Published var isReceivingData = false
    @Published var lastPacketTimestamp: Date?
    @Published var packetsPerSecond: Double = 0
    @Published var isMotionIdle = false  // True if no significant motion for >10s

    // MARK: - Settings

    /// Overall sensitivity multiplier (0.5 - 3.0)
    var sensitivityMultiplier: Double = 1.0

    /// Smoothing alpha for EMA filter (0.1 - 0.8)
    var smoothingAlpha: Double = 0.3

    /// Maximum dot displacement in pixels
    var maxDisplacement: CGFloat = 150

    /// Individual axis gains
    var lateralGain: Double = 300      // px per g-force
    var longitudinalGain: Double = 200  // px per g-force
    var verticalGain: Double = 100      // px per g-force
    var yawGain: Double = 50            // px per rad/s

    // MARK: - Private State

    private var smoothedAcceleration: Vector3 = .zero
    private var smoothedRotationRate: Vector3 = .zero

    private var packetCount = 0
    private var packetCountTimer: Timer?
    private var lastPacketCountReset = Date()

    private var lastMotionMagnitude: Double = 0
    private var idleStartTime: Date?
    private let idleThreshold: Double = 0.01  // g-force
    private let idleTimeRequired: TimeInterval = 10.0

    // Callback for processed motion output
    var onProcessedMotion: ((CGPoint, CGFloat) -> Void)?

    // MARK: - Initialization

    init() {
        startPacketCounter()
    }

    deinit {
        packetCountTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Process an incoming motion packet from iPhone
    func processPacket(_ packet: MotionPacket) {
        // Update state
        lastPacketTimestamp = Date()
        packetCount += 1

        // Only update isReceivingData if it changed (avoid flooding main thread)
        if !isReceivingData {
            DispatchQueue.main.async {
                self.isReceivingData = true
            }
        }

        // Apply smoothing
        smoothedAcceleration = applySmoothingFilter(
            newValue: packet.userAcceleration,
            previousValue: smoothedAcceleration
        )

        smoothedRotationRate = applySmoothingFilter(
            newValue: packet.rotationRate,
            previousValue: smoothedRotationRate
        )

        // Check for idle state
        updateIdleDetection(smoothedAcceleration)

        // Map to visual offset
        let (linearOffset, yawOffset) = mapToVisualOffset(
            acceleration: smoothedAcceleration,
            rotationRate: smoothedRotationRate
        )

        // Notify listener
        onProcessedMotion?(linearOffset, yawOffset)
    }

    /// Called when connection is lost - triggers smooth return to home
    func handleDisconnection() {
        DispatchQueue.main.async {
            self.isReceivingData = false
            self.packetsPerSecond = 0
        }

        smoothedAcceleration = .zero
        smoothedRotationRate = .zero
    }

    /// Reset all smoothing state
    func reset() {
        smoothedAcceleration = .zero
        smoothedRotationRate = .zero
        lastMotionMagnitude = 0
        idleStartTime = nil

        DispatchQueue.main.async {
            self.isMotionIdle = false
            self.isReceivingData = false
        }
    }

    // MARK: - Private Methods

    private func applySmoothingFilter(newValue: Vector3, previousValue: Vector3) -> Vector3 {
        Vector3(
            x: smoothingAlpha * newValue.x + (1 - smoothingAlpha) * previousValue.x,
            y: smoothingAlpha * newValue.y + (1 - smoothingAlpha) * previousValue.y,
            z: smoothingAlpha * newValue.z + (1 - smoothingAlpha) * previousValue.z
        )
    }

    private func mapToVisualOffset(acceleration: Vector3, rotationRate: Vector3) -> (CGPoint, CGFloat) {
        // Apply sensitivity multiplier
        let sensitivity = sensitivityMultiplier

        // Calculate linear offset
        // Lateral (x) -> horizontal screen movement (inverted: car left = dots right)
        let lateralOffset = -acceleration.x * lateralGain * sensitivity

        // Longitudinal (y) -> vertical screen movement
        let longitudinalOffset = -acceleration.y * longitudinalGain * sensitivity

        // Vertical (z) -> additional vertical jitter (reduced effect)
        let verticalOffset = -acceleration.z * verticalGain * sensitivity * 0.5

        // Combined linear offset
        var linearOffset = CGPoint(
            x: lateralOffset,
            y: longitudinalOffset + verticalOffset
        )

        // Clamp to max displacement
        let magnitude = sqrt(linearOffset.x * linearOffset.x + linearOffset.y * linearOffset.y)
        if magnitude > maxDisplacement {
            let scale = maxDisplacement / magnitude
            linearOffset.x *= scale
            linearOffset.y *= scale
        }

        // Calculate yaw offset (rotation around screen center)
        // Yaw rate (z) -> rotational displacement
        let yawOffset = CGFloat(-rotationRate.z * yawGain * sensitivity)

        return (linearOffset, yawOffset)
    }

    private func updateIdleDetection(_ acceleration: Vector3) {
        let magnitude = acceleration.magnitude

        if magnitude < idleThreshold {
            if idleStartTime == nil {
                idleStartTime = Date()
            } else if Date().timeIntervalSince(idleStartTime!) > idleTimeRequired {
                // Only update if state changed
                if !isMotionIdle {
                    DispatchQueue.main.async {
                        self.isMotionIdle = true
                    }
                }
            }
        } else {
            idleStartTime = nil
            // Only update if state changed
            if isMotionIdle {
                DispatchQueue.main.async {
                    self.isMotionIdle = false
                }
            }
        }

        lastMotionMagnitude = magnitude
    }

    private func startPacketCounter() {
        packetCountTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let elapsed = Date().timeIntervalSince(self.lastPacketCountReset)
            let rate = Double(self.packetCount) / elapsed

            DispatchQueue.main.async {
                self.packetsPerSecond = rate

                // Check if we've stopped receiving data
                if let lastPacket = self.lastPacketTimestamp,
                   Date().timeIntervalSince(lastPacket) > 2.0 {
                    self.isReceivingData = false
                }
            }

            self.packetCount = 0
            self.lastPacketCountReset = Date()
        }
    }
}
