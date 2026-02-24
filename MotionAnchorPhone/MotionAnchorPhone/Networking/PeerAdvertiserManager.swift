import Foundation
import MultipeerConnectivity
import Combine
import UIKit

/// Manages MultipeerConnectivity advertising for the iPhone app
/// iPhone acts as the advertiser, Mac browsers connect to it
final class PeerAdvertiserManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var connectionState: ConnectionState = .disconnected
    @Published var connectedPeerName: String?
    @Published var latestError: String?

    // MARK: - Private Properties

    private let serviceType = NetworkConstants.serviceType
    private var peerID: MCPeerID!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var session: MCSession!

    private var outputStream: OutputStream?
    private var streamQueue = DispatchQueue(label: "com.motionanchor.stream", qos: .userInteractive)

    // Reconnection tracking
    private var reconnectionAttempts = 0
    private let maxReconnectionAttempts = 3

    // Callback for when connection state changes
    var onConnectionStateChanged: ((ConnectionState) -> Void)?

    // MARK: - Initialization

    override init() {
        super.init()
        setupPeer()
    }

    private func setupPeer() {
        // Use device name as peer identifier
        peerID = MCPeerID(displayName: UIDevice.current.name)

        // Create session
        session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .none  // No encryption for lower latency
        )
        session.delegate = self

        // Create advertiser
        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: ["version": "1.0"],
            serviceType: serviceType
        )
        advertiser.delegate = self
    }

    // MARK: - Public Methods

    /// Start advertising to nearby Mac devices
    func startAdvertising() {
        print("DEBUG iPhone: startAdvertising called, state: \(connectionState)")
        guard connectionState == .disconnected else {
            print("DEBUG iPhone: Not starting - already in state: \(connectionState)")
            return
        }

        print("DEBUG iPhone: Starting to advertise with service type: \(serviceType)")
        advertiser.startAdvertisingPeer()
        DispatchQueue.main.async {
            self.connectionState = .searching
            self.onConnectionStateChanged?(.searching)
            print("DEBUG iPhone: Now advertising")
        }
    }

    /// Stop advertising
    func stopAdvertising() {
        advertiser.stopAdvertisingPeer()
        disconnect()
    }

    /// Disconnect from current session
    func disconnect() {
        outputStream?.close()
        outputStream = nil
        session.disconnect()

        DispatchQueue.main.async {
            self.connectionState = .disconnected
            self.connectedPeerName = nil
            self.onConnectionStateChanged?(.disconnected)
        }
    }

    /// Send motion packet to connected Mac
    func sendMotionPacket(_ packet: MotionPacket) {
        guard connectionState == .streaming || connectionState == .connected,
              let stream = outputStream else { return }

        streamQueue.async { [weak self] in
            let data = packet.toBinaryData()

            // Prepend message type and length
            var header = Data(capacity: 3)
            header.append(MessageType.motionData.rawValue)

            // Length as 2-byte big-endian
            var length = UInt16(data.count).bigEndian
            header.append(Data(bytes: &length, count: 2))

            // Write header + data
            let fullPacket = header + data

            fullPacket.withUnsafeBytes { buffer in
                if let baseAddress = buffer.baseAddress {
                    let bytesWritten = stream.write(baseAddress.assumingMemoryBound(to: UInt8.self), maxLength: fullPacket.count)
                    if bytesWritten < 0 {
                        DispatchQueue.main.async {
                            self?.latestError = "Stream write error"
                        }
                    }
                }
            }
        }
    }

    /// Send data using reliable (but slower) method
    func sendReliableData(_ data: Data, type: MessageType) {
        guard !session.connectedPeers.isEmpty else { return }

        var packet = Data()
        packet.append(type.rawValue)
        packet.append(data)

        do {
            try session.send(packet, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            DispatchQueue.main.async {
                self.latestError = "Send error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Private Methods

    private func setupOutputStream(to peer: MCPeerID) {
        do {
            print("DEBUG iPhone: Creating output stream to \(peer.displayName)")
            outputStream = try session.startStream(withName: "motion", toPeer: peer)
            // Don't schedule on main run loop - just open directly
            outputStream?.open()
            print("DEBUG iPhone: Output stream opened successfully")

            DispatchQueue.main.async {
                self.connectionState = .streaming
                self.onConnectionStateChanged?(.streaming)
            }
        } catch {
            print("DEBUG iPhone: Failed to open stream: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.latestError = "Failed to open stream: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension PeerAdvertiserManager: MCNearbyServiceAdvertiserDelegate {

    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        print("DEBUG iPhone: Received invitation from \(peerID.displayName)")

        // Accept the invitation with the existing session
        invitationHandler(true, session)
        print("DEBUG iPhone: Accepted invitation")

        DispatchQueue.main.async {
            self.connectionState = .connecting
            self.onConnectionStateChanged?(.connecting)
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async {
            self.latestError = "Advertising failed: \(error.localizedDescription)"
            self.connectionState = .disconnected
            self.onConnectionStateChanged?(.disconnected)
        }
    }
}

// MARK: - MCSessionDelegate

extension PeerAdvertiserManager: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("DEBUG iPhone: Session state changed to \(state.rawValue) for peer \(peerID.displayName)")
        DispatchQueue.main.async {
            switch state {
            case .connected:
                print("DEBUG iPhone: Connected to \(peerID.displayName)")
                self.connectedPeerName = peerID.displayName
                self.connectionState = .connected
                self.onConnectionStateChanged?(.connected)

                // Reset reconnection counter on successful connection
                self.reconnectionAttempts = 0

                // Delay stream setup to let connection stabilize
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self, self.connectionState == .connected else {
                        print("DEBUG iPhone: Connection lost before stream setup")
                        return
                    }
                    print("DEBUG iPhone: Starting output stream after delay")
                    self.setupOutputStream(to: peerID)
                }

            case .connecting:
                self.connectionState = .connecting
                self.onConnectionStateChanged?(.connecting)

            case .notConnected:
                if self.connectionState != .disconnected {
                    print("DEBUG iPhone: Connection lost, attempting to reconnect...")

                    // Clean up old stream
                    self.outputStream?.close()
                    self.outputStream = nil

                    // Connection was lost, attempt to reconnect
                    self.connectionState = .reconnecting
                    self.onConnectionStateChanged?(.reconnecting)

                    // Create fresh session to avoid stale state
                    self.session = MCSession(
                        peer: self.peerID,
                        securityIdentity: nil,
                        encryptionPreference: .none
                    )
                    self.session.delegate = self

                    // Resume advertising to allow reconnection
                    self.advertiser.stopAdvertisingPeer()
                    self.advertiser.startAdvertisingPeer()

                    // Increment attempt counter
                    self.reconnectionAttempts += 1
                    print("DEBUG iPhone: Restarted advertising for reconnection (attempt \(self.reconnectionAttempts))")

                    // Timeout for this reconnection attempt
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                        if self.connectionState == .reconnecting {
                            if self.reconnectionAttempts < self.maxReconnectionAttempts {
                                // Retry - restart advertising
                                print("DEBUG iPhone: Retrying reconnection (attempt \(self.reconnectionAttempts + 1))...")
                                self.advertiser.stopAdvertisingPeer()

                                // Create fresh session
                                self.session = MCSession(
                                    peer: self.peerID,
                                    securityIdentity: nil,
                                    encryptionPreference: .none
                                )
                                self.session.delegate = self

                                self.reconnectionAttempts += 1
                                self.advertiser.startAdvertisingPeer()
                            } else {
                                // Give up after max attempts
                                print("DEBUG iPhone: Reconnection failed after \(self.maxReconnectionAttempts) attempts")
                                self.connectionState = .disconnected
                                self.connectedPeerName = nil
                                self.reconnectionAttempts = 0
                                self.onConnectionStateChanged?(.disconnected)
                                self.advertiser.stopAdvertisingPeer()
                            }
                        }
                    }
                }

            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Handle incoming commands from Mac (e.g., settings sync)
        guard !data.isEmpty else { return }

        let messageType = MessageType(rawValue: data[0])
        _ = data.dropFirst() // payload for future use

        switch messageType {
        case .settingsSync:
            // Handle settings from Mac
            break
        case .disconnect:
            disconnect()
        default:
            break
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // iPhone doesn't receive streams, only sends
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used
    }
}
