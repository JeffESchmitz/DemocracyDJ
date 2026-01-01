import ComposableArchitecture
import Dependencies
import Shared
import struct MusicKit.MusicAuthorization

@Reducer
struct HostFeature {
    @ObservableState
    struct State: Equatable {
        var nowPlaying: Song?
        var queue: [QueueItem] = []
        var connectedPeers: [Peer] = []
        var isHosting: Bool = false
        var musicAuthorizationStatus: MusicAuthorization.Status = .notDetermined
        var myPeer: Peer

        init(
            myPeer: Peer,
            nowPlaying: Song? = nil,
            queue: [QueueItem] = [],
            connectedPeers: [Peer] = [],
            isHosting: Bool = false,
            musicAuthorizationStatus: MusicAuthorization.Status = .notDetermined
        ) {
            self.myPeer = myPeer
            self.nowPlaying = nowPlaying
            self.queue = queue
            self.connectedPeers = connectedPeers
            self.isHosting = isHosting
            self.musicAuthorizationStatus = musicAuthorizationStatus
        }

        init(
            displayName: String,
            nowPlaying: Song? = nil,
            queue: [QueueItem] = [],
            connectedPeers: [Peer] = [],
            isHosting: Bool = false,
            musicAuthorizationStatus: MusicAuthorization.Status = .notDetermined
        ) {
            self.init(
                myPeer: Peer(name: displayName),
                nowPlaying: nowPlaying,
                queue: queue,
                connectedPeers: connectedPeers,
                isHosting: isHosting,
                musicAuthorizationStatus: musicAuthorizationStatus
            )
        }
    }

    enum Action: Equatable {
        // Lifecycle
        case startHosting
        case stopHosting

        // Playback
        case playTapped
        case pauseTapped
        case skipTapped

        // Authorization
        case requestMusicAuthorization

        // Network
        case multipeerEvent(MultipeerEvent)

        // Internal
        case _processIntent(GuestIntent, from: Peer)
        case _authorizationStatusUpdated(MusicAuthorization.Status)
        case _broadcastSnapshot
    }

    @Dependency(\.multipeerClient) private var multipeerClient
    @Dependency(\.musicKitClient) private var musicKitClient

    private enum CancelID {
        case multipeerEvents
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            var effects: [Effect<Action>] = []
            var needsBroadcast = false

            switch action {
            case .startHosting:
                state.isHosting = true
                let displayName = state.myPeer.name
                effects.append(
                    .run { _ in
                        await multipeerClient.startHosting(displayName)
                    }
                )
                effects.append(
                    .run { send in
                        for await event in multipeerClient.events() {
                            await send(.multipeerEvent(event))
                        }
                    }
                    .cancellable(id: CancelID.multipeerEvents, cancelInFlight: true)
                )

            case .stopHosting:
                state.isHosting = false
                effects.append(.cancel(id: CancelID.multipeerEvents))
                effects.append(
                    .run { _ in
                        await multipeerClient.stop()
                    }
                )

            case .playTapped:
                break

            case .pauseTapped:
                break

            case .skipTapped:
                if state.queue.isEmpty {
                    if state.nowPlaying != nil {
                        state.nowPlaying = nil
                        needsBroadcast = true
                    }
                } else {
                    state.nowPlaying = state.queue.removeFirst().song
                    needsBroadcast = true
                }

            case .requestMusicAuthorization:
                return .run { send in
                    let status = await musicKitClient.requestAuthorization()
                    await send(._authorizationStatusUpdated(status))
                }

            case let .multipeerEvent(event):
                switch event {
                case let .peerConnected(peer):
                    if !state.connectedPeers.contains(peer) {
                        state.connectedPeers.append(peer)
                    }
                    // Always broadcast on peer connect to send a full snapshot.
                    needsBroadcast = true

                case let .peerDisconnected(peer):
                    if let index = state.connectedPeers.firstIndex(of: peer) {
                        state.connectedPeers.remove(at: index)
                        needsBroadcast = true
                    }

                case let .messageReceived(message, from: peer):
                    guard case let .intent(intent) = message else {
                        break
                    }
                    effects.append(.send(._processIntent(intent, from: peer)))

                case .peerDiscovered:
                    break
                }

            case let ._processIntent(intent, from: peer):
                switch intent {
                case let .suggestSong(song):
                    guard state.queue.first(where: { $0.id == song.id }) == nil else {
                        break
                    }
                    let item = QueueItem(
                        id: song.id,
                        song: song,
                        addedBy: peer,
                        voters: []
                    )
                    state.queue.append(item)
                    needsBroadcast = true

                case let .vote(songID):
                    guard let index = state.queue.firstIndex(where: { $0.id == songID }) else {
                        break
                    }
                    let peerID = peer.id
                    let inserted = state.queue[index].voters.insert(peerID).inserted
                    if inserted {
                        state.queue = sortedQueue(state.queue)
                        needsBroadcast = true
                    }
                }

            case let ._authorizationStatusUpdated(status):
                state.musicAuthorizationStatus = status

            case ._broadcastSnapshot:
                let snapshot = HostSnapshot(
                    nowPlaying: state.nowPlaying,
                    queue: state.queue,
                    connectedPeers: state.connectedPeers
                )
                return .run { _ in
                    try? await multipeerClient.send(.stateUpdate(snapshot), nil)
                }
            }

            if needsBroadcast {
                effects.append(.send(._broadcastSnapshot))
            }

            if effects.isEmpty {
                return .none
            }

            return .merge(effects)
        }
    }
}

private func sortedQueue(_ queue: [QueueItem]) -> [QueueItem] {
    let indexed = queue.enumerated().sorted { lhs, rhs in
        if lhs.element.voteCount != rhs.element.voteCount {
            return lhs.element.voteCount > rhs.element.voteCount
        }
        return lhs.offset < rhs.offset
    }
    return indexed.map { $0.element }
}
