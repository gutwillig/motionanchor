import Foundation
import MultipeerConnectivity
import Combine
import SwiftUI

/// Manages MultipeerConnectivity browsing for the Mac app
/// Mac acts as the browser, connecting to advertising iPhones
final class PeerConnectionManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var connectionState: ConnectionState = .disconnected
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var connectedPeerName: String?
    @Published var latestError: String?
    @Published var packetsReceived: Int = 0
    @Published var isStreamStale: Bool = false

    // MARK: - Private Properties

    private let serviceType = NetworkConstants.serviceType
    private var peerID: MCPeerID!
    private var browser: MCNearbyServiceBrowser!
    private var session: MCSession!

    private var inputStream: InputStream?
    private var streamBuffer = Data()
    private let streamQueue = DispatchQueue(label: "com.motionanchor.stream.read", qos: .userInteractive)

    // Last connected peer for auto-reconnect
    @AppStorage("lastConnectedPeerName") private var lastConnectedPeerName: String = ""

    // Reconnection tracking
    private var reconnectionAttempts = 0
    private let maxReconnectionAttempts = 3

    // Stale stream detection
    private var lastPacketTime: Date = Date()
    private var staleStreamTimer: Timer?
    private let staleStreamThreshold: TimeInterval = 5.0  // 5 seconds without data = stale

    // Callbacks
    var onMotionPacketReceived: ((MotionPacket) -> Void)?
    var onConnectionStateChanged: ((ConnectionState) -> Void)?

    // MARK: - Initialization

    override init() {
        super.init()
        setupPeer()
    }

    private func setupPeer() {
        peerID = MCPeerID(displayName: Host.current().localizedName ?? "Mac")

        session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .none
        )
        session.delegate = self

        browser = MCNearbyServiceBrowser(
            peer: peerID,
            serviceType: serviceType
        )
        browser.delegate = self
    }

    // MARK: - Public Methods

    /// Start browsing for nearby iPhones
    func startBrowsing() {
        print("DEBUG: startBrowsing called, current state: \(connectionState)")
        guard connectionState == .disconnected else {
            print("DEBUG: Not starting - already in state: \(connectionState)")
            return
        }

        // Update state first
        connectionState = .searching
        onConnectionStateChanged?(.searching)
        print("DEBUG: Now searching for peers")

        // Clear peers and start browsing on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.discoveredPeers.removeAll()
            }

            print("DEBUG: Starting to browse for peers with service type: \(self.serviceType)")
            self.browser.startBrowsingForPeers()
            print("DEBUG: Browser started")
        }
    }

    /// Stop browsing
    func stopBrowsing() {
        browser.stopBrowsingForPeers()

        if connectionState == .searching {
            DispatchQueue.main.async {
                self.connectionState = .disconnected
                self.onConnectionStateChanged?(.disconnected)
            }
        }
    }

    /// Connect to a specific peer
    func connect(to peer: MCPeerID) {
        print("DEBUG: Inviting peer: \(peer.displayName)")

        // Create a fresh session to avoid stale state issues
        session.disconnect()
        session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .none
        )
        session.delegate = self
        print("DEBUG: Created fresh session")

        browser.invitePeer(
            peer,
            to: session,
            withContext: nil,
            timeout: 30
        )

        DispatchQueue.main.async {
            self.connectionState = .connecting
            self.onConnectionStateChanged?(.connecting)
            print("DEBUG: Sent invitation, waiting for response...")
        }
    }

    /// Connect to the last known peer if found
    func autoConnect() {
        guard !lastConnectedPeerName.isEmpty else { return }

        startBrowsing()

        // Wait a moment for discovery, then try to connect
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }

            if let peer = self.discoveredPeers.first(where: { $0.displayName == self.lastConnectedPeerName }) {
                self.connect(to: peer)
            }
        }
    }

    /// Disconnect from current session
    func disconnect() {
        stopStaleStreamMonitoring()
        inputStream?.close()
        inputStream = nil
        streamBuffer.removeAll()
        session.disconnect()

        DispatchQueue.main.async {
            self.connectionState = .disconnected
            self.connectedPeerName = nil
            self.onConnectionStateChanged?(.disconnected)
        }
    }

    /// Send a command to the connected iPhone
    func sendCommand(_ type: MessageType, data: Data? = nil) {
        guard !session.connectedPeers.isEmpty else { return }

        var packet = Data()
        packet.append(type.rawValue)
        if let data = data {
            packet.append(data)
        }

        do {
            try session.send(packet, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            DispatchQueue.main.async {
                self.latestError = "Send error: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension PeerConnectionManager: MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        print("DEBUG: Found peer: \(peerID.displayName)")
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(peerID) {
                print("DEBUG: Adding peer to list: \(peerID.displayName)")
                self.discoveredPeers.append(peerID)
            }

            // Auto-connect to last known peer (when searching or reconnecting)
            if peerID.displayName == self.lastConnectedPeerName &&
               (self.connectionState == .searching || self.connectionState == .reconnecting) {
                print("DEBUG: Auto-connecting to last known peer: \(peerID.displayName)")
                self.connect(to: peerID)
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0 == peerID }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async {
            self.latestError = "Browse failed: \(error.localizedDescription)"
            self.connectionState = .disconnected
            self.onConnectionStateChanged?(.disconnected)
        }
    }
}

// MARK: - MCSessionDelegate

extension PeerConnectionManager: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("DEBUG: Session state changed to: \(state.rawValue) for peer: \(peerID.displayName)")
        DispatchQueue.main.async {
            switch state {
            case .connected:
                print("DEBUG: Connected to \(peerID.displayName)")
                self.connectedPeerName = peerID.displayName
                self.lastConnectedPeerName = peerID.displayName
                self.connectionState = .connected
                self.onConnectionStateChanged?(.connected)

                // Reset reconnection counter on successful connection
                self.reconnectionAttempts = 0

                // Stop browsing once connected
                self.browser.stopBrowsingForPeers()

            case .connecting:
                print("DEBUG: Connecting to peer...")
                self.connectionState = .connecting
                self.onConnectionStateChanged?(.connecting)

            case .notConnected:
                print("DEBUG: Not connected / disconnected from peer")
                if self.connectionState == .connected || self.connectionState == .streaming {
                    print("DEBUG: Connection was active, attempting to reconnect...")

                    // Connection was lost
                    self.connectionState = .reconnecting
                    self.onConnectionStateChanged?(.reconnecting)

                    // Clear old session state
                    self.inputStream?.close()
                    self.inputStream = nil
                    self.streamBuffer.removeAll()

                    // Create fresh session to avoid stale state
                    self.session.disconnect()
                    self.session = MCSession(
                        peer: self.peerID,
                        securityIdentity: nil,
                        encryptionPreference: .none
                    )
                    self.session.delegate = self

                    // Resume browsing to find the peer again
                    self.discoveredPeers.removeAll()
                    self.browser.stopBrowsingForPeers()
                    self.browser.startBrowsingForPeers()
                    print("DEBUG: Started browsing for reconnection")

                    // Increment attempt counter
                    self.reconnectionAttempts += 1
                    print("DEBUG: Reconnection attempt \(self.reconnectionAttempts) of \(self.maxReconnectionAttempts)")

                    // Timeout for this reconnection attempt
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                        if self.connectionState == .reconnecting {
                            if self.reconnectionAttempts < self.maxReconnectionAttempts {
                                // Retry - restart browsing
                                print("DEBUG: Retrying reconnection (attempt \(self.reconnectionAttempts + 1))...")
                                self.browser.stopBrowsingForPeers()

                                // Create fresh session
                                self.session.disconnect()
                                self.session = MCSession(
                                    peer: self.peerID,
                                    securityIdentity: nil,
                                    encryptionPreference: .none
                                )
                                self.session.delegate = self

                                self.reconnectionAttempts += 1
                                self.discoveredPeers.removeAll()
                                self.browser.startBrowsingForPeers()
                            } else {
                                // Give up after max attempts
                                print("DEBUG: Reconnection failed after \(self.maxReconnectionAttempts) attempts")
                                self.connectionState = .disconnected
                                self.connectedPeerName = nil
                                self.reconnectionAttempts = 0
                                self.onConnectionStateChanged?(.disconnected)
                                self.browser.stopBrowsingForPeers()
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
        // Handle reliable messages (commands, settings)
        guard !data.isEmpty else { return }

        let messageType = MessageType(rawValue: data[0])
        let payload = data.dropFirst()

        switch messageType {
        case .disconnect:
            disconnect()
        default:
            break
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("DEBUG: Stream received from \(peerID.displayName)")
        inputStream = stream

        // STEP 7: Add main thread callback (heavily throttled)
        streamQueue.async { [weak self] in
            stream.open()
            print("DEBUG: Stream opened")

            let bufferSize = 512
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            var localBuffer = [UInt8]()
            var packetCount = 0
            var lastCallbackTime = CACurrentMediaTime()
            var latestPacket: MotionPacket?

            while stream.streamStatus != .closed && stream.streamStatus != .error {
                if stream.hasBytesAvailable {
                    let bytesRead = stream.read(&buffer, maxLength: bufferSize)
                    if bytesRead > 0 {
                        localBuffer.append(contentsOf: buffer[0..<bytesRead])

                        // Parse complete packets
                        while localBuffer.count >= 47 {
                            let payloadBytes = Data(localBuffer[3..<47])
                            localBuffer.removeFirst(47)

                            // Decode full packet
                            if let packet = MotionPacket.fromBinaryData(payloadBytes) {
                                latestPacket = packet
                            }
                            packetCount += 1
                        }

                        if localBuffer.count > 1000 {
                            localBuffer.removeAll()
                        }

                        // Callback at max 20fps (every 0.05 seconds)
                        let now = CACurrentMediaTime()
                        if now - lastCallbackTime >= 0.05, let packet = latestPacket {
                            lastCallbackTime = now
                            DispatchQueue.main.async { [weak self] in
                                self?.packetsReceived = packetCount
                                self?.lastPacketTime = Date()
                                if self?.isStreamStale == true {
                                    self?.isStreamStale = false
                                }
                                self?.onMotionPacketReceived?(packet)
                            }
                        }

                        if packetCount % 200 == 0 && packetCount > 0 {
                            print("DEBUG: \(packetCount) packets")
                        }
                    }
                } else {
                    Thread.sleep(forTimeInterval: 0.05)
                }
            }
            print("DEBUG: Stream ended")
        }

        DispatchQueue.main.async {
            self.connectionState = .streaming
            self.onConnectionStateChanged?(.streaming)
            self.lastPacketTime = Date()
            self.startStaleStreamMonitoring()
        }
    }

    // MARK: - Stale Stream Detection

    private func startStaleStreamMonitoring() {
        staleStreamTimer?.invalidate()
        staleStreamTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkForStaleStream()
        }
    }

    private func stopStaleStreamMonitoring() {
        staleStreamTimer?.invalidate()
        staleStreamTimer = nil
        isStreamStale = false
    }

    private func checkForStaleStream() {
        guard connectionState == .streaming else { return }

        let timeSinceLastPacket = Date().timeIntervalSince(lastPacketTime)
        if timeSinceLastPacket > staleStreamThreshold {
            print("DEBUG: Stream stale - no packets for \(Int(timeSinceLastPacket)) seconds")

            if !isStreamStale {
                isStreamStale = true

                // Attempt to restart the stream by triggering reconnection
                print("DEBUG: Attempting to restart stale stream...")
                restartStaleStream()
            }
        }
    }

    private func restartStaleStream() {
        // Stop monitoring during restart
        stopStaleStreamMonitoring()

        // Close the current stream
        inputStream?.close()
        inputStream = nil
        streamBuffer.removeAll()

        // Trigger a reconnection
        connectionState = .reconnecting
        onConnectionStateChanged?(.reconnecting)

        // Create fresh session
        session.disconnect()
        session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .none
        )
        session.delegate = self

        // Start browsing to reconnect
        reconnectionAttempts = 0
        discoveredPeers.removeAll()
        browser.stopBrowsingForPeers()
        browser.startBrowsingForPeers()
    }

    /// Parse a single motion packet from stream data (called on background thread)
    private func parseMotionPacket(_ data: Data) -> MotionPacket? {
        streamBuffer.append(data)

        // Process packets from buffer, return the latest one
        var latestPacket: MotionPacket?
        while streamBuffer.count >= 3 {
            let messageType = streamBuffer[0]
            let length = UInt16(streamBuffer[1]) << 8 | UInt16(streamBuffer[2])

            let totalLength = 3 + Int(length)
            guard streamBuffer.count >= totalLength else { break }

            let packetData = streamBuffer.subdata(in: 3..<totalLength)
            streamBuffer.removeFirst(totalLength)

            if messageType == MessageType.motionData.rawValue {
                if let packet = MotionPacket.fromBinaryData(packetData) {
                    latestPacket = packet
                }
            }
        }
        return latestPacket
    }

    private func processMotionData(_ data: Data) {
        streamBuffer.append(data)

        // Process packets from buffer
        while streamBuffer.count >= 3 {
            let messageType = streamBuffer[0]
            let length = UInt16(streamBuffer[1]) << 8 | UInt16(streamBuffer[2])

            let totalLength = 3 + Int(length)
            guard streamBuffer.count >= totalLength else { break }

            let packetData = streamBuffer.subdata(in: 3..<totalLength)
            streamBuffer.removeFirst(totalLength)

            if messageType == MessageType.motionData.rawValue {
                // TEMPORARILY DISABLED - testing if motion processing causes freeze
                // if let packet = MotionPacket.fromBinaryData(packetData) {
                //     DispatchQueue.main.async { [weak self] in
                //         self?.onMotionPacketReceived?(packet)
                //     }
                // }
            }
        }
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used
    }
}

// MARK: - StreamDelegate

extension PeerConnectionManager: StreamDelegate {

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        guard let inputStream = aStream as? InputStream else { return }

        switch eventCode {
        case .hasBytesAvailable:
            readFromStream(inputStream)

        case .errorOccurred:
            DispatchQueue.main.async {
                self.latestError = "Stream error"
            }

        case .endEncountered:
            inputStream.close()
            self.inputStream = nil

        default:
            break
        }
    }

    private func readFromStream(_ stream: InputStream) {
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                streamBuffer.append(contentsOf: buffer[0..<bytesRead])
                processStreamBuffer()
            }
        }
    }

    private func processStreamBuffer() {
        // Packet format: [type: 1 byte][length: 2 bytes][data: N bytes]
        while streamBuffer.count >= 3 {
            let messageType = streamBuffer[0]
            let length = UInt16(streamBuffer[1]) << 8 | UInt16(streamBuffer[2])

            let totalLength = 3 + Int(length)
            guard streamBuffer.count >= totalLength else { break }

            // Extract packet data
            let packetData = streamBuffer.subdata(in: 3..<totalLength)
            streamBuffer.removeFirst(totalLength)

            // Process based on type
            if messageType == MessageType.motionData.rawValue {
                if let packet = MotionPacket.fromBinaryData(packetData) {
                    DispatchQueue.main.async {
                        self.packetsReceived += 1
                    }
                    onMotionPacketReceived?(packet)
                }
            }
        }
    }
}
