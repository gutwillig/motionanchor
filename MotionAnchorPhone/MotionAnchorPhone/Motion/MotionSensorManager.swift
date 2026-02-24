import Foundation
import CoreMotion
import Combine

/// Manages CoreMotion sensor data collection and processing
final class MotionSensorManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private var motionQueue = OperationQueue()

    @Published var isRunning = false
    @Published var currentPacket: MotionPacket?
    @Published var isCalibrated = false
    @Published var isCalibrating = false  // True during background calibration
    @Published var phoneIsStable = true
    @Published var samplingRate: Double = NetworkConstants.defaultSamplingRate

    /// Callback for each new motion packet
    var onMotionPacket: ((MotionPacket) -> Void)?

    // Calibration reference values
    private var referenceGravity: CMAcceleration?
    private var referenceAttitude: CMAttitude?

    // Low-pass filter state for acceleration
    private var filteredAcceleration: Vector3 = .zero
    private let accelerationFilterAlpha: Double = 0.1

    // Stability detection
    private var accelerationVarianceBuffer: [Double] = []
    private let stabilityBufferSize = 30
    private let stabilityThreshold: Double = 0.05

    // Phone pickup detection
    private var attitudeChangeBuffer: [Double] = []
    private let pickupThreshold: Double = 0.5  // radians

    init() {
        motionQueue.name = "com.motionanchor.motion"
        motionQueue.maxConcurrentOperationCount = 1
    }

    /// Check if device motion is available
    var isDeviceMotionAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }

    /// Start collecting motion data
    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion not available")
            return
        }

        let interval = 1.0 / samplingRate
        motionManager.deviceMotionUpdateInterval = interval

        // Use sensor fusion with magnetometer for best accuracy
        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: motionQueue
        ) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                if let error = error {
                    print("Motion error: \(error.localizedDescription)")
                }
                return
            }

            self.processMotion(motion)
        }

        DispatchQueue.main.async {
            self.isRunning = true
        }
    }

    /// Stop collecting motion data
    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
        DispatchQueue.main.async {
            self.isRunning = false
            self.currentPacket = nil
        }
    }

    /// Calibrate the sensor to current phone position (instant, for when motion is already running)
    func calibrate() {
        guard let motion = motionManager.deviceMotion else { return }

        referenceGravity = motion.gravity
        referenceAttitude = motion.attitude.copy() as? CMAttitude

        DispatchQueue.main.async {
            self.isCalibrated = true
            self.isCalibrating = false
        }
    }

    /// Perform calibration in background without interrupting any existing streaming
    /// This will start motion updates temporarily if not running, calibrate, then restore state
    func calibrateInBackground(completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            self.isCalibrating = true
        }

        // Check actual motion manager state (more reliable than our isRunning flag)
        let wasActive = motionManager.isDeviceMotionActive

        // Start motion if not already running
        if !wasActive {
            guard motionManager.isDeviceMotionAvailable else {
                DispatchQueue.main.async {
                    self.isCalibrating = false
                }
                completion?()
                return
            }

            let interval = 1.0 / samplingRate
            motionManager.deviceMotionUpdateInterval = interval
            motionManager.startDeviceMotionUpdates(
                using: .xArbitraryZVertical,
                to: motionQueue
            ) { [weak self] motion, _ in
                guard let self = self, let motion = motion else { return }
                self.processMotion(motion)
            }
        }

        // Wait a moment for sensor to stabilize, then calibrate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            self.calibrate()

            // If we started motion just for calibration, stop it
            if !wasActive {
                self.motionManager.stopDeviceMotionUpdates()
            }

            completion?()
        }
    }

    /// Reset calibration
    func resetCalibration() {
        referenceGravity = nil
        referenceAttitude = nil
        DispatchQueue.main.async {
            self.isCalibrated = false
        }
    }

    /// Set sampling rate (30Hz or 60Hz)
    func setSamplingRate(_ rate: Double) {
        let wasRunning = isRunning
        if wasRunning {
            stopMotionUpdates()
        }

        samplingRate = rate

        if wasRunning {
            startMotionUpdates()
        }
    }

    // MARK: - Private Methods

    private func processMotion(_ motion: CMDeviceMotion) {
        // Transform acceleration to vehicle reference frame
        let transformedAcceleration = transformToVehicleFrame(
            userAcceleration: motion.userAcceleration,
            gravity: motion.gravity
        )

        // Apply low-pass filter to remove hand tremor
        let filteredAccel = applyLowPassFilter(transformedAcceleration)

        // Check for phone stability
        updateStabilityDetection(filteredAccel)

        // Check for phone pickup
        checkForPhonePickup(motion.attitude)

        // Create packet with transformed data
        let packet = MotionPacket(
            timestamp: motion.timestamp,
            userAcceleration: filteredAccel,
            rotationRate: Vector3(
                x: motion.rotationRate.x,
                y: motion.rotationRate.y,
                z: motion.rotationRate.z
            ),
            attitude: Attitude(
                roll: motion.attitude.roll,
                pitch: motion.attitude.pitch,
                yaw: motion.attitude.yaw
            )
        )

        DispatchQueue.main.async {
            self.currentPacket = packet
        }

        onMotionPacket?(packet)
    }

    /// Transform acceleration from phone coordinate frame to vehicle reference frame
    /// This ensures consistent motion data regardless of phone orientation
    private func transformToVehicleFrame(
        userAcceleration: CMAcceleration,
        gravity: CMAcceleration
    ) -> Vector3 {
        // Use gravity vector to determine phone orientation
        // and rotate acceleration to a consistent frame

        // Normalize gravity vector
        let gMag = sqrt(gravity.x * gravity.x + gravity.y * gravity.y + gravity.z * gravity.z)
        guard gMag > 0.1 else {
            return Vector3(
                x: userAcceleration.x,
                y: userAcceleration.y,
                z: userAcceleration.z
            )
        }

        let gNorm = (x: gravity.x / gMag, y: gravity.y / gMag, z: gravity.z / gMag)

        // Create rotation matrix to align gravity with Z axis
        // For simplicity, we use a projection approach:

        // If phone is flat (gravity pointing along Z), minimal transformation needed
        // If phone is tilted, we project the acceleration onto the horizontal plane

        // Calculate the horizontal plane components
        // The gravity vector tells us which way is "down" in the phone's frame

        // For vehicle motion:
        // - Lateral (x): perpendicular to gravity and forward direction
        // - Longitudinal (y): perpendicular to gravity, aligned with forward
        // - Vertical (z): aligned with gravity (but inverted for "up")

        // Using the gravity vector, we can decompose the user acceleration
        // into components relative to the ground

        // Dot product of userAcceleration with gravity gives vertical component
        let verticalComponent = userAcceleration.x * gNorm.x +
                                userAcceleration.y * gNorm.y +
                                userAcceleration.z * gNorm.z

        // Remove vertical component to get horizontal acceleration
        let horizontalX = userAcceleration.x - verticalComponent * gNorm.x
        let horizontalY = userAcceleration.y - verticalComponent * gNorm.y
        let horizontalZ = userAcceleration.z - verticalComponent * gNorm.z

        // The horizontal magnitude represents lateral/longitudinal motion
        // For MVP, we treat the primary horizontal axis as lateral (x)
        // and secondary as longitudinal (y)

        // Calculate horizontal magnitude in phone's XY plane projected onto ground
        let lateralAccel = sqrt(horizontalX * horizontalX + horizontalY * horizontalY)
        let longitudinalAccel = horizontalZ

        // Determine sign based on dominant direction
        let lateralSign = horizontalX >= 0 ? 1.0 : -1.0

        return Vector3(
            x: lateralAccel * lateralSign,  // Lateral (left/right)
            y: longitudinalAccel,            // Longitudinal (forward/back)
            z: -verticalComponent             // Vertical (up/down), inverted so up is positive
        )
    }

    /// Apply exponential moving average low-pass filter
    private func applyLowPassFilter(_ input: Vector3) -> Vector3 {
        filteredAcceleration = Vector3(
            x: accelerationFilterAlpha * input.x + (1 - accelerationFilterAlpha) * filteredAcceleration.x,
            y: accelerationFilterAlpha * input.y + (1 - accelerationFilterAlpha) * filteredAcceleration.y,
            z: accelerationFilterAlpha * input.z + (1 - accelerationFilterAlpha) * filteredAcceleration.z
        )
        return filteredAcceleration
    }

    /// Detect if phone is in a stable position (not being held/moved by hand)
    private func updateStabilityDetection(_ acceleration: Vector3) {
        let variance = acceleration.magnitude

        accelerationVarianceBuffer.append(variance)
        if accelerationVarianceBuffer.count > stabilityBufferSize {
            accelerationVarianceBuffer.removeFirst()
        }

        guard accelerationVarianceBuffer.count == stabilityBufferSize else { return }

        // Calculate variance of the magnitude buffer
        let mean = accelerationVarianceBuffer.reduce(0, +) / Double(stabilityBufferSize)
        let varianceSum = accelerationVarianceBuffer.reduce(0) { $0 + pow($1 - mean, 2) }
        let computedVariance = varianceSum / Double(stabilityBufferSize)

        DispatchQueue.main.async {
            self.phoneIsStable = computedVariance < self.stabilityThreshold
        }
    }

    /// Detect if phone has been picked up (sudden attitude change)
    private func checkForPhonePickup(_ attitude: CMAttitude) {
        guard let reference = referenceAttitude else { return }

        // Calculate angular difference from reference
        let rollDiff = abs(attitude.roll - reference.roll)
        let pitchDiff = abs(attitude.pitch - reference.pitch)

        let totalDiff = sqrt(rollDiff * rollDiff + pitchDiff * pitchDiff)

        if totalDiff > pickupThreshold {
            // Phone has been significantly moved, pause tracking briefly
            DispatchQueue.main.async {
                self.phoneIsStable = false
            }

            // Auto-recalibrate after a short delay if phone becomes stable
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                if self?.phoneIsStable == false {
                    // Could trigger recalibration here if desired
                }
            }
        }
    }
}
