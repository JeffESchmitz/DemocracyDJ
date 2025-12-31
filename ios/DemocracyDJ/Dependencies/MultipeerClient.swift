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

    /// Sends a message to a specific peer, or broadcasts to all peers when `to == nil`.
    var send: @Sendable (_ message: MeshMessage, _ to: Peer?) async throws -> Void

    /// Returns a stream of networking events. Subscribe once per feature lifecycle.
    var events: @Sendable () -> AsyncStream<MultipeerEvent>
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

    /// A message was received from a connected peer.
    case messageReceived(MeshMessage, from: Peer)
}

// MARK: - DependencyKey

extension MultipeerClient: DependencyKey {
    static let liveValue: MultipeerClient = .live
    static let testValue: MultipeerClient = .mock
    static let previewValue: MultipeerClient = .preview
}

extension DependencyValues {
    var multipeerClient: MultipeerClient {
        get { self[MultipeerClient.self] }
        set { self[MultipeerClient.self] = newValue }
    }
}

// MARK: - Test/Preview Implementations

extension MultipeerClient {
    // Note: `.live` is implemented in MultipeerClient+Live.swift

    /// No-op for unit tests. Never yields events, never finishes.
    /// Tests needing events should override via withDependencies.
    static let mock = MultipeerClient(
        startHosting: { _ in },
        startBrowsing: { _ in },
        stop: { },
        send: { _, _ in },
        events: {
            // Never-finishing stream - avoids "stream ended" surprises
            AsyncStream { _ in }
        }
    )

    /// For SwiftUI previews. Will be enhanced in "Create Mock MultipeerClient" issue.
    static let preview = MultipeerClient(
        startHosting: { _ in },
        startBrowsing: { _ in },
        stop: { },
        send: { _, _ in },
        events: {
            AsyncStream { _ in }
        }
    )
}
