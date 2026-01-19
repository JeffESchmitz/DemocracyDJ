@preconcurrency import MultipeerConnectivity
import Dependencies
import Foundation
import Shared

// MARK: - MultipeerError

/// Errors thrown by MultipeerClient transport operations.
/// Rule: Transport-level failures throw; protocol/data failures are logged.
enum MultipeerError: Error, Equatable {
    case notConnected
    case peerNotFound(String)
    case encodingFailed
}

// MARK: - MultipeerActor

/// Actor that owns all MultipeerConnectivity objects.
/// MCPeerID NEVER escapes this actor—all external code uses Peer.
actor MultipeerActor {
    // MARK: - Constants

    private static let serviceType = "democracy-dj"
    private static let discoveryInfo = ["version": "1"]

    // MARK: - State

    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var localPeerID: MCPeerID?

    /// MCPeerID → Peer mapping
    private var peerMap: [MCPeerID: Peer] = [:]
    /// Peer.id → MCPeerID reverse mapping for send()
    private var reversePeerMap: [String: MCPeerID] = [:]

    private var continuation: AsyncStream<MultipeerEvent>.Continuation?
    private var eventStreamInstance: AsyncStream<MultipeerEvent>?
    private var isHosting: Bool = false

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // Delegate helpers (must be retained)
    private var sessionDelegate: SessionDelegateHelper?
    private var browserDelegate: BrowserDelegateHelper?
    private var advertiserDelegate: AdvertiserDelegateHelper?

    // MARK: - Lifecycle Methods

    /// Start advertising as host with the given display name.
    func startHosting(displayName: String) {
        // Log lifecycle transitions for field diagnostics.
        Logger.multipeer.info("Start hosting as \(displayName, privacy: .public)")
        isHosting = true
        setupSession(displayName: displayName)

        guard let localPeerID else { return }

        let delegate = AdvertiserDelegateHelper(actor: self, session: session)
        advertiserDelegate = delegate

        advertiser = MCNearbyServiceAdvertiser(
            peer: localPeerID,
            discoveryInfo: Self.discoveryInfo,
            serviceType: Self.serviceType
        )
        advertiser?.delegate = delegate
        advertiser?.startAdvertisingPeer()
    }

    /// Start browsing for hosts with the given display name.
    func startBrowsing(displayName: String) {
        Logger.multipeer.info("Start browsing as \(displayName, privacy: .public)")
        isHosting = false
        setupSession(displayName: displayName)

        guard let localPeerID else { return }

        let delegate = BrowserDelegateHelper(actor: self)
        browserDelegate = delegate

        browser = MCNearbyServiceBrowser(
            peer: localPeerID,
            serviceType: Self.serviceType
        )
        browser?.delegate = delegate
        browser?.startBrowsingForPeers()
    }

    /// Stop all networking activity.
    func stop() {
        Logger.multipeer.info("Stop multipeer activity")
        // Stop advertiser
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        advertiserDelegate = nil

        // Stop browser
        browser?.stopBrowsingForPeers()
        browser = nil
        browserDelegate = nil

        // Emit disconnect events before finishing stream
        for peer in peerMap.values {
            continuation?.yield(.peerDisconnected(peer))
        }

        // Disconnect session
        session?.disconnect()
        session = nil
        sessionDelegate = nil

        // Clear state
        localPeerID = nil
        peerMap.removeAll()
        reversePeerMap.removeAll()
        isHosting = false

        // Finish stream (Option A: restart requires new actor)
        continuation?.finish()
        continuation = nil
        eventStreamInstance = nil
    }

    // MARK: - Messaging

    /// Send a message to a specific peer, or broadcast to all if peer is nil.
    func send(_ message: MeshMessage, to peer: Peer?) throws {
        guard let session else {
            throw MultipeerError.notConnected
        }

        let data: Data
        do {
            data = try encoder.encode(message)
        } catch {
            throw MultipeerError.encodingFailed
        }

        let targetPeers: [MCPeerID]
        if let peer {
            guard let mcPeerID = reversePeerMap[peer.id] else {
                throw MultipeerError.peerNotFound(peer.id)
            }
            targetPeers = [mcPeerID]
        } else {
            // Broadcast to all connected peers
            targetPeers = session.connectedPeers
        }

        guard !targetPeers.isEmpty else {
            // No peers to send to - not an error for broadcasts
            return
        }

        try session.send(data, toPeers: targetPeers, with: .reliable)
    }

    /// Invite a discovered host to connect.
    func invite(_ host: Peer) throws {
        guard let session else {
            throw MultipeerError.notConnected
        }

        guard let browser else {
            throw MultipeerError.notConnected
        }

        guard let mcPeerID = reversePeerMap[host.id] else {
            throw MultipeerError.peerNotFound(host.id)
        }

        browser.invitePeer(mcPeerID, to: session, withContext: nil, timeout: 30)
    }

    // MARK: - Event Stream

    /// Returns the event stream (single-subscriber model).
    func eventStream() -> AsyncStream<MultipeerEvent> {
        if let stream = eventStreamInstance {
            return stream
        }

        let stream = AsyncStream { [weak self] newContinuation in
            Task { [weak self] in
                await self?.setContinuation(newContinuation)
            }
        }
        eventStreamInstance = stream
        return stream
    }

    private func setContinuation(_ newContinuation: AsyncStream<MultipeerEvent>.Continuation) {
        self.continuation = newContinuation

        newContinuation.onTermination = { [weak self] _ in
            Task { [weak self] in
                await self?.handleStreamTermination()
            }
        }
    }

    private func handleStreamTermination() {
        self.continuation = nil
        self.eventStreamInstance = nil
    }

    private func emit(_ event: MultipeerEvent) {
        continuation?.yield(event)
    }

    // MARK: - Private Setup

    private func setupSession(displayName: String) {
        // Clean up existing session
        session?.disconnect()

        localPeerID = MCPeerID(displayName: displayName)

        let delegate = SessionDelegateHelper(actor: self)
        sessionDelegate = delegate

        session = MCSession(
            peer: localPeerID!,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        session?.delegate = delegate
    }

    // MARK: - Internal Handlers (called from delegate helpers)

    func handlePeerStateChange(_ mcPeerID: MCPeerID, state: MCSessionState) {
        switch state {
        case .connected:
            // Ensure peer is in map
            if peerMap[mcPeerID] == nil {
                let peer = Peer(id: mcPeerID.displayName, name: mcPeerID.displayName)
                peerMap[mcPeerID] = peer
                reversePeerMap[peer.id] = mcPeerID
            }
            if let peer = peerMap[mcPeerID] {
                emit(.peerConnected(peer))
            }

        case .notConnected:
            if let peer = peerMap.removeValue(forKey: mcPeerID) {
                reversePeerMap.removeValue(forKey: peer.id)
                emit(.peerDisconnected(peer))
            }

        case .connecting:
            // Transitional state - no event
            break

        @unknown default:
            break
        }
    }

    func handleReceivedData(_ data: Data, from mcPeerID: MCPeerID) {
        guard let peer = peerMap[mcPeerID] else {
            Logger.multipeer.warning("Received data from unknown peer")
            return
        }

        do {
            let message = try decoder.decode(MeshMessage.self, from: data)
            emit(.messageReceived(message, from: peer))
        } catch {
            Logger.multipeer.error("Failed to decode message: \(error)")
        }
    }

    func handlePeerDiscovered(_ mcPeerID: MCPeerID, discoveryInfo: [String: String]?) {
        // Create Peer and add to maps
        let peer = Peer(id: mcPeerID.displayName, name: mcPeerID.displayName)
        peerMap[mcPeerID] = peer
        reversePeerMap[peer.id] = mcPeerID

        emit(.peerDiscovered(peer))
    }

    func handlePeerLost(_ mcPeerID: MCPeerID) {
        // Remove from maps if exists (peer lost before connecting)
        if let peer = peerMap.removeValue(forKey: mcPeerID) {
            reversePeerMap.removeValue(forKey: peer.id)
            emit(.peerLost(peer))
        }
    }

    /// Called after host auto-accepts an invitation (handler already called in delegate).
    func handleInvitationAccepted(from mcPeerID: MCPeerID) {
        // Create Peer for the connecting device
        let peer = Peer(id: mcPeerID.displayName, name: mcPeerID.displayName)
        peerMap[mcPeerID] = peer
        reversePeerMap[peer.id] = mcPeerID
    }

    func handleBrowserError(_ error: Error) {
        Logger.multipeer.error("Browser error: \(error)")
    }

    func handleAdvertiserError(_ error: Error) {
        Logger.multipeer.error("Advertiser error: \(error)")
    }
}

// MARK: - Delegate Helpers

/// Delegate helper that forwards MCSession callbacks to the actor.
/// Uses nonisolated methods with Task dispatch to bridge to actor context.
private final class SessionDelegateHelper: NSObject, MCSessionDelegate, @unchecked Sendable {
    private let actor: MultipeerActor

    init(actor: MultipeerActor) {
        self.actor = actor
    }

    func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChange state: MCSessionState
    ) {
        Task {
            await actor.handlePeerStateChange(peerID, state: state)
        }
    }

    func session(
        _ session: MCSession,
        didReceive data: Data,
        fromPeer peerID: MCPeerID
    ) {
        Task {
            await actor.handleReceivedData(data, from: peerID)
        }
    }

    func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {
        // Not used
    }

    func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {
        // Not used
    }

    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {
        // Not used
    }
}

/// Delegate helper that forwards MCNearbyServiceBrowser callbacks to the actor.
private final class BrowserDelegateHelper: NSObject, MCNearbyServiceBrowserDelegate, @unchecked Sendable {
    private let actor: MultipeerActor

    init(actor: MultipeerActor) {
        self.actor = actor
    }

    func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        Task {
            await actor.handlePeerDiscovered(peerID, discoveryInfo: info)
        }
    }

    func browser(
        _ browser: MCNearbyServiceBrowser,
        lostPeer peerID: MCPeerID
    ) {
        Task {
            await actor.handlePeerLost(peerID)
        }
    }

    func browser(
        _ browser: MCNearbyServiceBrowser,
        didNotStartBrowsingForPeers error: Error
    ) {
        Task {
            await actor.handleBrowserError(error)
        }
    }
}

/// Delegate helper that forwards MCNearbyServiceAdvertiser callbacks to the actor.
/// Handles invitations synchronously since the handler is not Sendable.
private final class AdvertiserDelegateHelper: NSObject, MCNearbyServiceAdvertiserDelegate, @unchecked Sendable {
    private let actor: MultipeerActor
    private weak var session: MCSession?

    init(actor: MultipeerActor, session: MCSession?) {
        self.actor = actor
        self.session = session
    }

    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        // Host auto-accepts all invitations synchronously
        // (handler must be called promptly per Apple docs)
        invitationHandler(true, session)

        // Notify actor about the accepted peer
        Task {
            await actor.handleInvitationAccepted(from: peerID)
        }
    }

    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: Error
    ) {
        Task {
            await actor.handleAdvertiserError(error)
        }
    }
}

// MARK: - MultipeerClient.live Extension

extension MultipeerClient {
    /// Live implementation backed by MultipeerActor with real MultipeerConnectivity.
    static var live: MultipeerClient {
        let actor = MultipeerActor()

        return MultipeerClient(
            startHosting: { displayName in
                await actor.startHosting(displayName: displayName)
            },
            startBrowsing: { displayName in
                await actor.startBrowsing(displayName: displayName)
            },
            stop: {
                await actor.stop()
            },
            invite: { host in
                try await actor.invite(host)
            },
            send: { message, peer in
                try await actor.send(message, to: peer)
            },
            events: {
                await actor.eventStream()
            }
        )
    }
}
