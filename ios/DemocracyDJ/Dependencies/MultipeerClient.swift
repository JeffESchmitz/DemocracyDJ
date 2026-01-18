import Dependencies
import Shared

// MARK: - MultipeerClient

/// TCA dependency for mesh networking. Abstracts MultipeerConnectivity.
/// MCPeerID never escapes this interface—all domain code uses `Peer`.
struct MultipeerClient: Sendable {
    /// Start advertising as host with the given display name.
    var startHosting: @Sendable (_ displayName: String) async -> Void

    /// Start browsing for hosts with the given display name.
    var startBrowsing: @Sendable (_ displayName: String) async -> Void

    /// Stop all networking activity (advertising, browsing, session).
    var stop: @Sendable () async -> Void

    /// Invite a discovered host to connect.
    var invite: @Sendable (_ host: Peer) async throws -> Void

    /// Sends a message to a specific peer, or broadcasts to all peers when `to == nil`.
    var send: @Sendable (_ message: MeshMessage, _ to: Peer?) async throws -> Void

    /// Returns a stream of networking events. Subscribe once per feature lifecycle.
    /// Single-subscriber model: only one consumer should iterate the stream.
    /// The stream is finished when stop() is called.
    var events: @Sendable () async -> AsyncStream<MultipeerEvent>
}

// MARK: - MultipeerEvent

/// Events emitted by the multipeer networking layer.
/// These are the only networking events that TCA reducers see.
enum MultipeerEvent: Sendable, Equatable {
    /// A peer was discovered during browsing (not yet connected).
    case peerDiscovered(Peer)

    /// A peer successfully connected to the session.
    case peerConnected(Peer)

    /// A peer disconnected from the session.
    case peerDisconnected(Peer)

    /// A discovered peer was lost before connecting.
    case peerLost(Peer)

    /// A message was received from a connected peer.
    case messageReceived(MeshMessage, from: Peer)
}

// MARK: - DependencyKey

extension MultipeerClient: DependencyKey {
    static let liveValue: MultipeerClient = .live
    static let testValue: MultipeerClient = .mock()
    static let previewValue: MultipeerClient = .preview
}

extension DependencyValues {
    var multipeerClient: MultipeerClient {
        get { self[MultipeerClient.self] }
        set { self[MultipeerClient.self] = newValue }
    }
}

// MARK: - Preview Data

/// Preview data scoped to MultipeerClient concerns only.
/// Song/Queue/HostSnapshot data belongs in HostFeature+PreviewData (Issue #9+).
enum PreviewData {
    /// Simulated peers for previews: Diego, Eduardo, Santiago
    static let peers: [Peer] = [
        Peer(id: "preview-peer-1", name: "Diego's iPhone"),
        Peer(id: "preview-peer-2", name: "Eduardo's iPad"),
        Peer(id: "preview-peer-3", name: "Santiago's iPhone"),
    ]
}

// MARK: - Test/Preview Implementations

extension MultipeerClient {
    // Note: `.live` is implemented in MultipeerClient+Live.swift

    /// Configurable mock for unit tests.
    /// - Parameters:
    ///   - events: Custom event stream (default: finishes immediately)
    ///   - onStartHosting: Closure called when startHosting is invoked
    ///   - onStartBrowsing: Closure called when startBrowsing is invoked
    ///   - onStop: Closure called when stop is invoked
    ///   - onInvite: Closure called when invite is invoked
    ///   - onSend: Closure called when send is invoked
    static func mock(
        events: @escaping @Sendable () async -> AsyncStream<MultipeerEvent> = {
            AsyncStream { $0.finish() }
        },
        onStartHosting: @escaping @Sendable (String) async -> Void = { _ in },
        onStartBrowsing: @escaping @Sendable (String) async -> Void = { _ in },
        onStop: @escaping @Sendable () async -> Void = {},
        onInvite: @escaping @Sendable (Peer) async throws -> Void = { _ in },
        onSend: @escaping @Sendable (MeshMessage, Peer?) async throws -> Void = { _, _ in }
    ) -> Self {
        MultipeerClient(
            startHosting: onStartHosting,
            startBrowsing: onStartBrowsing,
            stop: onStop,
            invite: onInvite,
            send: onSend,
            events: events
        )
    }

    /// Preview mock with 3 simulated connected peers.
    /// Preview skips discovery phase and emits peers as already connected.
    static var preview: Self {
        MultipeerClient(
            startHosting: { _ in },
            startBrowsing: { _ in },
            stop: {},
            invite: { _ in },
            send: { _, _ in },
            events: {
                AsyncStream { continuation in
                    // Preview skips discovery phase - peers appear already connected
                    Task {
                        for peer in PreviewData.peers {
                            continuation.yield(.peerConnected(peer))
                            try? await Task.sleep(for: .milliseconds(100))
                        }
                        // Stream stays open (never finishes)
                    }
                }
            }
        )
    }
}
