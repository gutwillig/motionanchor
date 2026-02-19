import Foundation

/// Represents motion data captured from the iPhone's sensors
/// Sent at 60Hz from iPhone to Mac
public struct MotionPacket: Codable {
    /// Timestamp in seconds since reference date
    public let timestamp: Double

    /// User acceleration (gravity removed) in g-force
    /// x: lateral (left/right), y: longitudinal (forward/back), z: vertical (up/down)
    public let userAcceleration: Vector3

    /// Rotation rate in radians/second
    /// x: pitch rate, y: roll rate, z: yaw rate
    public let rotationRate: Vector3

    /// Device attitude in radians
    /// roll: rotation around longitudinal axis
    /// pitch: rotation around lateral axis
    /// yaw: rotation around vertical axis
    public let attitude: Attitude

    public init(timestamp: Double, userAcceleration: Vector3, rotationRate: Vector3, attitude: Attitude) {
        self.timestamp = timestamp
        self.userAcceleration = userAcceleration
        self.rotationRate = rotationRate
        self.attitude = attitude
    }

    // MARK: - Compact Binary Encoding

    /// Encodes the packet as compact binary data (52 bytes)
    /// Format: timestamp(8) + ua.xyz(12) + rr.xyz(12) + att.rpy(12) + checksum(8)
    public func toBinaryData() -> Data {
        var data = Data(capacity: 52)

        // Timestamp (8 bytes)
        var ts = timestamp
        data.append(Data(bytes: &ts, count: 8))

        // User acceleration (12 bytes)
        var uaX = Float(userAcceleration.x)
        var uaY = Float(userAcceleration.y)
        var uaZ = Float(userAcceleration.z)
        data.append(Data(bytes: &uaX, count: 4))
        data.append(Data(bytes: &uaY, count: 4))
        data.append(Data(bytes: &uaZ, count: 4))

        // Rotation rate (12 bytes)
        var rrX = Float(rotationRate.x)
        var rrY = Float(rotationRate.y)
        var rrZ = Float(rotationRate.z)
        data.append(Data(bytes: &rrX, count: 4))
        data.append(Data(bytes: &rrY, count: 4))
        data.append(Data(bytes: &rrZ, count: 4))

        // Attitude (12 bytes)
        var roll = Float(attitude.roll)
        var pitch = Float(attitude.pitch)
        var yaw = Float(attitude.yaw)
        data.append(Data(bytes: &roll, count: 4))
        data.append(Data(bytes: &pitch, count: 4))
        data.append(Data(bytes: &yaw, count: 4))

        return data
    }

    /// Decodes a packet from compact binary data
    public static func fromBinaryData(_ data: Data) -> MotionPacket? {
        guard data.count >= 44 else { return nil }

        var offset = 0

        // Timestamp
        let timestamp: Double = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: Double.self)
        }
        offset += 8

        // User acceleration
        let uaX: Float = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: Float.self)
        }
        offset += 4
        let uaY: Float = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: Float.self)
        }
        offset += 4
        let uaZ: Float = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: Float.self)
        }
        offset += 4

        // Rotation rate
        let rrX: Float = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: Float.self)
        }
        offset += 4
        let rrY: Float = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: Float.self)
        }
        offset += 4
        let rrZ: Float = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: Float.self)
        }
        offset += 4

        // Attitude
        let roll: Float = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: Float.self)
        }
        offset += 4
        let pitch: Float = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: Float.self)
        }
        offset += 4
        let yaw: Float = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: Float.self)
        }

        return MotionPacket(
            timestamp: timestamp,
            userAcceleration: Vector3(x: Double(uaX), y: Double(uaY), z: Double(uaZ)),
            rotationRate: Vector3(x: Double(rrX), y: Double(rrY), z: Double(rrZ)),
            attitude: Attitude(roll: Double(roll), pitch: Double(pitch), yaw: Double(yaw))
        )
    }
}

// MARK: - Supporting Types

public struct Vector3: Codable, Equatable {
    public let x: Double
    public let y: Double
    public let z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = Vector3(x: 0, y: 0, z: 0)

    public var magnitude: Double {
        sqrt(x * x + y * y + z * z)
    }

    public func scaled(by factor: Double) -> Vector3 {
        Vector3(x: x * factor, y: y * factor, z: z * factor)
    }

    public func clamped(to maxMagnitude: Double) -> Vector3 {
        let mag = magnitude
        if mag <= maxMagnitude { return self }
        let scale = maxMagnitude / mag
        return scaled(by: scale)
    }
}

public struct Attitude: Codable, Equatable {
    public let roll: Double
    public let pitch: Double
    public let yaw: Double

    public init(roll: Double, pitch: Double, yaw: Double) {
        self.roll = roll
        self.pitch = pitch
        self.yaw = yaw
    }

    public static let zero = Attitude(roll: 0, pitch: 0, yaw: 0)
}

// MARK: - JSON Coding Keys (for compact JSON format)

extension MotionPacket {
    enum CodingKeys: String, CodingKey {
        case timestamp = "t"
        case userAcceleration = "ua"
        case rotationRate = "rr"
        case attitude = "att"
    }
}
