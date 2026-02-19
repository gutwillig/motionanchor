import Foundation

/// Network configuration constants shared between Mac and iPhone apps
public enum NetworkConstants {
    /// MultipeerConnectivity service type (max 15 chars, lowercase alphanumeric + hyphens)
    public static let serviceType = "motionanchor"

    /// Bonjour service type for fallback UDP streaming
    public static let bonjourServiceType = "_motionanchor._udp"

    /// Default UDP port for fallback streaming
    public static let udpPort: UInt16 = 41234

    /// Target data streaming rate in Hz
    public static let defaultSamplingRate: Double = 60.0

    /// Low-power sampling rate in Hz
    public static let lowPowerSamplingRate: Double = 30.0

    /// Maximum acceptable latency in milliseconds
    public static let maxAcceptableLatencyMs: Double = 50.0

    /// Reconnection timeout in seconds
    public static let reconnectionTimeoutSeconds: Double = 30.0

    /// Heartbeat interval for connection health monitoring
    public static let heartbeatIntervalSeconds: Double = 1.0
}

/// Connection state shared between both apps
public enum ConnectionState: String, Codable {
    case disconnected
    case searching
    case connecting
    case connected
    case streaming
    case reconnecting

    public var displayName: String {
        switch self {
        case .disconnected: return "Not Connected"
        case .searching: return "Searching..."
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .streaming: return "Streaming"
        case .reconnecting: return "Reconnecting..."
        }
    }

    public var isActive: Bool {
        switch self {
        case .connected, .streaming: return true
        default: return false
        }
    }
}

/// Message types for MultipeerConnectivity communication
public enum MessageType: UInt8, Codable {
    case motionData = 0x01
    case heartbeat = 0x02
    case calibrationStart = 0x03
    case calibrationComplete = 0x04
    case settingsSync = 0x05
    case disconnect = 0xFF
}
