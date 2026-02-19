import Foundation

/// Generates simulated motion data for testing/preview without iPhone connection
final class SimulatedMotion {

    enum SimulationMode {
        case gentleDriving      // Slow curves, gradual braking
        case cityDriving        // Quick turns, stop-and-go
        case highway            // Smooth lane changes, constant speed
        case bumpyRoad          // Vertical oscillation
        case idle               // Minimal motion with slight drift
    }

    var mode: SimulationMode = .gentleDriving
    var isRunning = false

    private var timer: Timer?
    private var elapsedTime: Double = 0
    private let updateInterval: TimeInterval = 1.0 / 60.0

    var onMotionPacket: ((MotionPacket) -> Void)?

    // MARK: - Control

    func start() {
        guard !isRunning else { return }

        isRunning = true
        elapsedTime = 0

        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.generatePacket()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    // MARK: - Generation

    private func generatePacket() {
        elapsedTime += updateInterval

        let packet: MotionPacket

        switch mode {
        case .gentleDriving:
            packet = generateGentleDriving()
        case .cityDriving:
            packet = generateCityDriving()
        case .highway:
            packet = generateHighway()
        case .bumpyRoad:
            packet = generateBumpyRoad()
        case .idle:
            packet = generateIdle()
        }

        onMotionPacket?(packet)
    }

    private func generateGentleDriving() -> MotionPacket {
        // Slow sinusoidal lateral motion (gentle curves)
        let lateralAccel = 0.05 * sin(elapsedTime * 0.5)

        // Occasional gentle braking/accelerating
        let longitudinalAccel = 0.03 * sin(elapsedTime * 0.3 + 1.0)

        // Very slight vertical motion
        let verticalAccel = 0.01 * sin(elapsedTime * 2.0)

        // Slow yaw rate for turning
        let yawRate = 0.02 * sin(elapsedTime * 0.5)

        return MotionPacket(
            timestamp: Date().timeIntervalSinceReferenceDate,
            userAcceleration: Vector3(x: lateralAccel, y: longitudinalAccel, z: verticalAccel),
            rotationRate: Vector3(x: 0, y: 0, z: yawRate),
            attitude: .zero
        )
    }

    private func generateCityDriving() -> MotionPacket {
        // Sharper lateral motion (turns at intersections)
        let turnPhase = elapsedTime.truncatingRemainder(dividingBy: 10.0)
        let lateralAccel: Double
        if turnPhase < 2 {
            lateralAccel = 0.15 * sin(turnPhase * .pi / 2)  // Sharp turn
        } else {
            lateralAccel = 0.02 * sin(elapsedTime * 2.0)    // Minor adjustments
        }

        // Stop-and-go pattern
        let stopPhase = elapsedTime.truncatingRemainder(dividingBy: 15.0)
        let longitudinalAccel: Double
        if stopPhase < 3 {
            longitudinalAccel = -0.2 * (1 - stopPhase / 3)  // Braking
        } else if stopPhase < 5 {
            longitudinalAccel = 0  // Stopped
        } else if stopPhase < 8 {
            longitudinalAccel = 0.15 * ((stopPhase - 5) / 3)  // Accelerating
        } else {
            longitudinalAccel = 0.02  // Cruising
        }

        // More vertical bumps (road imperfections)
        let verticalAccel = 0.03 * sin(elapsedTime * 4.0) + 0.02 * sin(elapsedTime * 7.0)

        // Yaw following lateral
        let yawRate = 0.05 * sin(elapsedTime * 0.7)

        return MotionPacket(
            timestamp: Date().timeIntervalSinceReferenceDate,
            userAcceleration: Vector3(x: lateralAccel, y: longitudinalAccel, z: verticalAccel),
            rotationRate: Vector3(x: 0, y: 0, z: yawRate),
            attitude: .zero
        )
    }

    private func generateHighway() -> MotionPacket {
        // Smooth, slow lane changes
        let lateralAccel = 0.03 * sin(elapsedTime * 0.2)

        // Very minimal longitudinal (constant speed)
        let longitudinalAccel = 0.01 * sin(elapsedTime * 0.1)

        // Low vertical
        let verticalAccel = 0.005 * sin(elapsedTime * 1.5)

        // Gentle yaw
        let yawRate = 0.01 * sin(elapsedTime * 0.2)

        return MotionPacket(
            timestamp: Date().timeIntervalSinceReferenceDate,
            userAcceleration: Vector3(x: lateralAccel, y: longitudinalAccel, z: verticalAccel),
            rotationRate: Vector3(x: 0, y: 0, z: yawRate),
            attitude: .zero
        )
    }

    private func generateBumpyRoad() -> MotionPacket {
        // Mix of frequencies for realistic road vibration
        let verticalAccel = 0.08 * sin(elapsedTime * 5.0) +
                            0.04 * sin(elapsedTime * 12.0) +
                            0.02 * sin(elapsedTime * 20.0)

        // Some lateral shake
        let lateralAccel = 0.02 * sin(elapsedTime * 6.0)

        // Minor longitudinal
        let longitudinalAccel = 0.01 * sin(elapsedTime * 3.0)

        return MotionPacket(
            timestamp: Date().timeIntervalSinceReferenceDate,
            userAcceleration: Vector3(x: lateralAccel, y: longitudinalAccel, z: verticalAccel),
            rotationRate: Vector3(x: 0.01 * sin(elapsedTime * 4.0), y: 0, z: 0),
            attitude: .zero
        )
    }

    private func generateIdle() -> MotionPacket {
        // Very subtle drift to show the system is active
        let noise = 0.002

        return MotionPacket(
            timestamp: Date().timeIntervalSinceReferenceDate,
            userAcceleration: Vector3(
                x: noise * sin(elapsedTime * 0.7),
                y: noise * sin(elapsedTime * 0.5),
                z: noise * sin(elapsedTime * 0.3)
            ),
            rotationRate: Vector3(
                x: 0,
                y: 0,
                z: noise * 0.5 * sin(elapsedTime * 0.4)
            ),
            attitude: .zero
        )
    }
}
