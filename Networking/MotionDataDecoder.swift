import Foundation

/// Decodes incoming motion data packets from the iPhone
struct MotionDataDecoder {

    enum DecodingError: Error {
        case insufficientData
        case invalidFormat
        case checksumMismatch
    }

    /// Decode a motion packet from binary data
    static func decode(_ data: Data) throws -> MotionPacket {
        guard let packet = MotionPacket.fromBinaryData(data) else {
            throw DecodingError.invalidFormat
        }
        return packet
    }

    /// Decode a motion packet from JSON data
    static func decodeJSON(_ data: Data) throws -> MotionPacket {
        let decoder = JSONDecoder()
        return try decoder.decode(MotionPacket.self, from: data)
    }

    /// Validate packet timestamp (check for excessive latency)
    static func validateTimestamp(_ packet: MotionPacket, maxLatencyMs: Double = 100) -> Bool {
        let now = Date().timeIntervalSinceReferenceDate
        let latency = (now - packet.timestamp) * 1000  // Convert to ms

        // Allow for some clock drift, but flag very old packets
        return latency < maxLatencyMs && latency > -1000  // -1000 allows for clock being ahead
    }

    /// Calculate latency for a packet in milliseconds
    static func calculateLatency(_ packet: MotionPacket) -> Double {
        let now = Date().timeIntervalSinceReferenceDate
        return (now - packet.timestamp) * 1000
    }
}

// MARK: - Stream Buffer Decoder

/// Handles decoding packets from a continuous stream buffer
final class StreamBufferDecoder {

    private var buffer = Data()

    /// Add data to the buffer
    func append(_ data: Data) {
        buffer.append(data)
    }

    /// Try to decode all complete packets from the buffer
    /// Returns decoded packets and removes them from the buffer
    func decodeAvailablePackets() -> [MotionPacket] {
        var packets: [MotionPacket] = []

        // Packet format: [type: 1 byte][length: 2 bytes big-endian][data: N bytes]
        while buffer.count >= 3 {
            let messageType = buffer[0]
            let length = Int(buffer[1]) << 8 | Int(buffer[2])

            let totalLength = 3 + length
            guard buffer.count >= totalLength else { break }

            // Only decode motion data packets
            if messageType == MessageType.motionData.rawValue {
                let packetData = buffer.subdata(in: 3..<totalLength)
                if let packet = MotionPacket.fromBinaryData(packetData) {
                    packets.append(packet)
                }
            }

            buffer.removeFirst(totalLength)
        }

        return packets
    }

    /// Clear the buffer
    func reset() {
        buffer.removeAll()
    }

    /// Current buffer size
    var bufferSize: Int {
        buffer.count
    }
}
