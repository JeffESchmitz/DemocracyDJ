import ComposableArchitecture
import Foundation
import Shared

@Reducer
struct GuestFeature {
    @ObservableState
    struct State: Equatable {
        /// Local peer identity owned by this reducer.
        /// Created on startBrowsing; never inferred from network events.
        var myPeer: Peer?

        var connectionStatus: ConnectionStatus = .disconnected
        var hostSnapshot: HostSnapshot?
        var pendingVotes: Set<String> = []
        var availableHosts: IdentifiedArrayOf<Peer> = []

        enum ConnectionStatus: Equatable {
            case disconnected
            case browsing
            case connecting(host: Peer)
            case connected(host: Peer)
            case failed(reason: String)
        }
    }

    enum Action {
        // MARK: - Lifecycle
        case startBrowsing(displayName: String)
        case stopBrowsing
        case connectToHost(Peer)

        // MARK: - User Actions
        case voteTapped(songID: String)
        case suggestSongTapped(Song)

        // MARK: - Network
        case multipeerEvent(MultipeerEvent)

        // MARK: - Internal
        case _snapshotReceived(HostSnapshot)
        case _connectionFailed(String)
    }

    @Dependency(\.multipeerClient) var multipeerClient
    @Dependency(\.uuid) var uuid

    private enum CancelID {
        case multipeerEvents
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            // MARK: - Lifecycle

            case let .startBrowsing(displayName):
                state.myPeer = Peer(
                    id: uuid().uuidString,
                    name: displayName
                )
                state.connectionStatus = .browsing
                state.availableHosts.removeAll()
                state.hostSnapshot = nil
                state.pendingVotes.removeAll()

                return .run { send in
                    await multipeerClient.startBrowsing(displayName)
                    for await event in await multipeerClient.events() {
                        await send(.multipeerEvent(event))
                    }
                }
                .cancellable(id: CancelID.multipeerEvents, cancelInFlight: true)

            case .stopBrowsing:
                state.connectionStatus = .disconnected
                state.availableHosts.removeAll()
                state.hostSnapshot = nil
                state.pendingVotes.removeAll()

                return .merge(
                    .run { _ in
                        await multipeerClient.stop()
                    },
                    .cancel(id: CancelID.multipeerEvents)
                )

            case let .connectToHost(host):
                state.connectionStatus = .connecting(host: host)

                return .run { send in
                    do {
                        try await multipeerClient.invite(host)
                    } catch {
                        await send(._connectionFailed("Connection failed"))
                    }
                }

            case let ._connectionFailed(reason):
                state.connectionStatus = .failed(reason: reason)
                return .none

            // MARK: - User Actions

            case let .voteTapped(songID):
                guard case let .connected(host) = state.connectionStatus else {
                    return .none
                }

                // Optimistic UI: record vote immediately
                state.pendingVotes.insert(songID)

                return .run { _ in
                    let intent = GuestIntent.vote(songID: songID)
                    let message = MeshMessage.intent(intent)
                    try await multipeerClient.send(message, host)
                }

            case let .suggestSongTapped(song):
                guard case let .connected(host) = state.connectionStatus else {
                    return .none
                }

                return .run { _ in
                    let intent = GuestIntent.suggestSong(song)
                    let message = MeshMessage.intent(intent)
                    try await multipeerClient.send(message, host)
                }

            // MARK: - Network Events

            case let .multipeerEvent(event):
                switch event {

                case let .peerDiscovered(peer):
                    if !state.availableHosts.contains(peer) {
                        state.availableHosts.append(peer)
                    }
                    return .none

                case let .peerConnected(peer):
                    if case .connecting = state.connectionStatus {
                        state.connectionStatus = .connected(host: peer)
                        state.availableHosts.removeAll()
                    }
                    return .none

                case .peerDisconnected:
                    state.connectionStatus = .disconnected
                    state.hostSnapshot = nil
                    state.pendingVotes.removeAll()
                    return .none

                case let .messageReceived(message, _):
                    switch message {
                    case let .stateUpdate(snapshot):
                        return .send(._snapshotReceived(snapshot))
                    case .intent:
                        // Guests never process intents
                        return .none
                    }
                }

            // MARK: - Internal

            case let ._snapshotReceived(snapshot):
                state.hostSnapshot = snapshot
                state.pendingVotes.removeAll()
                return .none
            }
        }
    }
}
