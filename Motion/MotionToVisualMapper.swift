import Foundation
import CoreGraphics

/// Maps motion sensor data to visual dot displacement
/// Encapsulates the physics-to-visual translation logic
struct MotionToVisualMapper {

    // MARK: - Configuration

    struct Config {
        /// Pixels per g-force for lateral (left/right) acceleration
        var lateralGain: Double = 300

        /// Pixels per g-force for longitudinal (forward/back) acceleration
        var longitudinalGain: Double = 200

        /// Pixels per g-force for vertical (up/down) acceleration
        var verticalGain: Double = 100

        /// Pixels offset per radian/second of yaw rotation
        var yawGain: Double = 50

        /// Overall sensitivity multiplier
        var sensitivityMultiplier: Double = 1.0

        /// Maximum displacement from home position in pixels
        var maxDisplacement: CGFloat = 150

        static let low = Config(
            lateralGain: 150,
            longitudinalGain: 100,
            verticalGain: 50,
            yawGain: 25,
            sensitivityMultiplier: 0.5,
            maxDisplacement: 100
        )

        static let medium = Config()  // Default values

        static let high = Config(
            lateralGain: 450,
            longitudinalGain: 300,
            verticalGain: 150,
            yawGain: 75,
            sensitivityMultiplier: 1.5,
            maxDisplacement: 200
        )
    }

    var config: Config

    init(config: Config = .medium) {
        self.config = config
    }

    // MARK: - Mapping

    /// Result of motion mapping
    struct VisualOutput {
        /// Linear offset from home position (x = horizontal, y = vertical)
        let linearOffset: CGPoint

        /// Rotational offset around screen center in radians
        let rotationalOffset: CGFloat

        static let zero = VisualOutput(linearOffset: .zero, rotationalOffset: 0)
    }

    /// Map motion data to visual output
    func map(acceleration: Vector3, rotationRate: Vector3) -> VisualOutput {
        let sensitivity = config.sensitivityMultiplier

        // Calculate lateral offset (left/right sway, turns)
        // Invert so that when car turns left, dots move right (matching visual scene)
        let lateralOffset = -acceleration.x * config.lateralGain * sensitivity

        // Calculate longitudinal offset (braking/accelerating)
        // Braking = positive forward accel = dots move down
        let longitudinalOffset = -acceleration.y * config.longitudinalGain * sensitivity

        // Calculate vertical offset (bumps)
        // Reduced effect since vertical motion is less nauseating
        let verticalOffset = -acceleration.z * config.verticalGain * sensitivity * 0.5

        // Combine into linear offset
        var linearOffset = CGPoint(
            x: lateralOffset,
            y: longitudinalOffset + verticalOffset
        )

        // Clamp to max displacement
        linearOffset = clampToMaxDisplacement(linearOffset)

        // Calculate yaw rotation effect
        // Yaw rate (turning) causes dots to orbit slightly around screen center
        let yawOffset = CGFloat(-rotationRate.z * config.yawGain * sensitivity)

        return VisualOutput(
            linearOffset: linearOffset,
            rotationalOffset: yawOffset
        )
    }

    /// Map a motion packet directly
    func map(packet: MotionPacket) -> VisualOutput {
        map(acceleration: packet.userAcceleration, rotationRate: packet.rotationRate)
    }

    // MARK: - Helpers

    private func clampToMaxDisplacement(_ point: CGPoint) -> CGPoint {
        let magnitude = sqrt(point.x * point.x + point.y * point.y)
        guard magnitude > config.maxDisplacement else { return point }

        let scale = config.maxDisplacement / magnitude
        return CGPoint(x: point.x * scale, y: point.y * scale)
    }
}

// MARK: - Preset Configurations

extension MotionToVisualMapper.Config {

    /// Preset for highway driving (smoother, larger movements)
    static let highway = MotionToVisualMapper.Config(
        lateralGain: 200,
        longitudinalGain: 250,
        verticalGain: 50,
        yawGain: 30,
        sensitivityMultiplier: 0.8,
        maxDisplacement: 120
    )

    /// Preset for city driving (quicker response, more turning)
    static let city = MotionToVisualMapper.Config(
        lateralGain: 400,
        longitudinalGain: 200,
        verticalGain: 100,
        yawGain: 80,
        sensitivityMultiplier: 1.2,
        maxDisplacement: 180
    )

    /// Preset for train travel (smooth lateral, minimal vertical)
    static let train = MotionToVisualMapper.Config(
        lateralGain: 350,
        longitudinalGain: 150,
        verticalGain: 30,
        yawGain: 40,
        sensitivityMultiplier: 1.0,
        maxDisplacement: 150
    )

    /// Preset for bus (bumpy, stop-and-go)
    static let bus = MotionToVisualMapper.Config(
        lateralGain: 300,
        longitudinalGain: 300,
        verticalGain: 150,
        yawGain: 60,
        sensitivityMultiplier: 1.3,
        maxDisplacement: 200
    )
}
