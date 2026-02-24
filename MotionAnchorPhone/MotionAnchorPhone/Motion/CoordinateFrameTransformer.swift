import Foundation
import CoreMotion

/// Transforms phone sensor data to vehicle-relative coordinate frame
/// Handles phone orientation independence - works whether phone is flat, tilted, or vertical
final class CoordinateFrameTransformer {

    // Reference frame captured during calibration
    private var referenceGravity: (x: Double, y: Double, z: Double)?
    private var referenceForward: (x: Double, y: Double, z: Double)?

    // Rotation matrix from phone frame to vehicle frame
    private var rotationMatrix: [[Double]] = [
        [1, 0, 0],
        [0, 1, 0],
        [0, 0, 1]
    ]

    var isCalibrated: Bool {
        referenceGravity != nil
    }

    /// Calibrate the transformer with current phone orientation
    /// Should be called when phone is placed stably in the vehicle
    func calibrate(with deviceMotion: CMDeviceMotion) {
        let gravity = deviceMotion.gravity

        // Store normalized gravity as reference "down" direction
        let gMag = sqrt(gravity.x * gravity.x + gravity.y * gravity.y + gravity.z * gravity.z)
        guard gMag > 0.5 else { return }

        referenceGravity = (
            x: gravity.x / gMag,
            y: gravity.y / gMag,
            z: gravity.z / gMag
        )

        // Calculate rotation matrix to align phone frame with vehicle frame
        computeRotationMatrix()
    }

    /// Reset calibration
    func reset() {
        referenceGravity = nil
        referenceForward = nil
        rotationMatrix = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    }

    /// Transform user acceleration from phone frame to vehicle frame
    /// Returns: (lateral, longitudinal, vertical) in vehicle coordinates
    func transformAcceleration(_ acceleration: CMAcceleration) -> Vector3 {
        guard referenceGravity != nil else {
            // No calibration, return raw values
            return Vector3(x: acceleration.x, y: acceleration.y, z: acceleration.z)
        }

        // Apply rotation matrix
        let transformed = multiplyMatrixVector(rotationMatrix, (acceleration.x, acceleration.y, acceleration.z))

        return Vector3(
            x: transformed.0,  // Lateral (positive = right)
            y: transformed.1,  // Longitudinal (positive = forward)
            z: transformed.2   // Vertical (positive = up)
        )
    }

    /// Transform rotation rate from phone frame to vehicle frame
    func transformRotationRate(_ rotationRate: CMRotationRate) -> Vector3 {
        guard referenceGravity != nil else {
            return Vector3(x: rotationRate.x, y: rotationRate.y, z: rotationRate.z)
        }

        let transformed = multiplyMatrixVector(rotationMatrix, (rotationRate.x, rotationRate.y, rotationRate.z))

        return Vector3(
            x: transformed.0,  // Pitch rate
            y: transformed.1,  // Roll rate
            z: transformed.2   // Yaw rate
        )
    }

    // MARK: - Private Methods

    private func computeRotationMatrix() {
        guard let g = referenceGravity else { return }

        // Create orthonormal basis where:
        // Z-axis = negative gravity (up in vehicle frame)
        // X-axis = perpendicular to Z, pointing "right" in vehicle
        // Y-axis = perpendicular to Z and X, pointing "forward" in vehicle

        // Z axis (up) = -gravity
        let zAxis = (x: -g.x, y: -g.y, z: -g.z)

        // Choose an arbitrary reference for forward (phone's Y axis projected onto horizontal plane)
        // This assumes phone's "up" direction roughly aligns with vehicle forward when placed flat
        var yCandidate = (x: 0.0, y: 1.0, z: 0.0)

        // Project yCandidate onto horizontal plane (perpendicular to zAxis)
        let dot = yCandidate.x * zAxis.x + yCandidate.y * zAxis.y + yCandidate.z * zAxis.z
        var yAxis = (
            x: yCandidate.x - dot * zAxis.x,
            y: yCandidate.y - dot * zAxis.y,
            z: yCandidate.z - dot * zAxis.z
        )

        // Normalize Y axis
        var yMag = sqrt(yAxis.x * yAxis.x + yAxis.y * yAxis.y + yAxis.z * yAxis.z)
        if yMag < 0.1 {
            // Y candidate was parallel to Z, use X instead
            yCandidate = (x: 1.0, y: 0.0, z: 0.0)
            let dot2 = yCandidate.x * zAxis.x + yCandidate.y * zAxis.y + yCandidate.z * zAxis.z
            yAxis = (
                x: yCandidate.x - dot2 * zAxis.x,
                y: yCandidate.y - dot2 * zAxis.y,
                z: yCandidate.z - dot2 * zAxis.z
            )
            yMag = sqrt(yAxis.x * yAxis.x + yAxis.y * yAxis.y + yAxis.z * yAxis.z)
        }

        yAxis = (x: yAxis.x / yMag, y: yAxis.y / yMag, z: yAxis.z / yMag)

        // X axis = Y cross Z (right-handed coordinate system)
        let xAxis = (
            x: yAxis.y * zAxis.z - yAxis.z * zAxis.y,
            y: yAxis.z * zAxis.x - yAxis.x * zAxis.z,
            z: yAxis.x * zAxis.y - yAxis.y * zAxis.x
        )

        // Build rotation matrix (phone frame to vehicle frame)
        // Each row is one of the vehicle frame axes expressed in phone coordinates
        rotationMatrix = [
            [xAxis.x, xAxis.y, xAxis.z],  // Vehicle X (lateral) in phone coords
            [yAxis.x, yAxis.y, yAxis.z],  // Vehicle Y (longitudinal) in phone coords
            [zAxis.x, zAxis.y, zAxis.z]   // Vehicle Z (vertical) in phone coords
        ]
    }

    private func multiplyMatrixVector(_ matrix: [[Double]], _ vector: (Double, Double, Double)) -> (Double, Double, Double) {
        let x = matrix[0][0] * vector.0 + matrix[0][1] * vector.1 + matrix[0][2] * vector.2
        let y = matrix[1][0] * vector.0 + matrix[1][1] * vector.1 + matrix[1][2] * vector.2
        let z = matrix[2][0] * vector.0 + matrix[2][1] * vector.1 + matrix[2][2] * vector.2
        return (x, y, z)
    }
}
