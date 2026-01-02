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
        var isPlaying: Bool = false
        var playbackStatus: PlaybackStatus = .notPlaying
        var musicAuthorizationStatus: MusicAuthorization.Status = .notDetermined
        var isSearchSheetPresented: Bool = false
        var searchQuery: String = ""
        var searchResults: [Song] = []
        var isSearching: Bool = false
        var myPeer: Peer

        init(
            myPeer: Peer,
            nowPlaying: Song? = nil,
            queue: [QueueItem] = [],
            connectedPeers: [Peer] = [],
            isHosting: Bool = false,
            isPlaying: Bool = false,
            playbackStatus: PlaybackStatus = .notPlaying,
            musicAuthorizationStatus: MusicAuthorization.Status = .notDetermined,
            isSearchSheetPresented: Bool = false,
            searchQuery: String = "",
            searchResults: [Song] = [],
            isSearching: Bool = false
        ) {
            self.myPeer = myPeer
            self.nowPlaying = nowPlaying
            self.queue = queue
            self.connectedPeers = connectedPeers
            self.isHosting = isHosting
            self.isPlaying = isPlaying
            self.playbackStatus = playbackStatus
            self.musicAuthorizationStatus = musicAuthorizationStatus
            self.isSearchSheetPresented = isSearchSheetPresented
            self.searchQuery = searchQuery
            self.searchResults = searchResults
            self.isSearching = isSearching
        }

        init(
            displayName: String,
            nowPlaying: Song? = nil,
            queue: [QueueItem] = [],
            connectedPeers: [Peer] = [],
            isHosting: Bool = false,
            isPlaying: Bool = false,
            playbackStatus: PlaybackStatus = .notPlaying,
            musicAuthorizationStatus: MusicAuthorization.Status = .notDetermined,
            isSearchSheetPresented: Bool = false,
            searchQuery: String = "",
            searchResults: [Song] = [],
            isSearching: Bool = false
        ) {
            self.init(
                myPeer: Peer(name: displayName),
                nowPlaying: nowPlaying,
                queue: queue,
                connectedPeers: connectedPeers,
                isHosting: isHosting,
                isPlaying: isPlaying,
                playbackStatus: playbackStatus,
                musicAuthorizationStatus: musicAuthorizationStatus,
                isSearchSheetPresented: isSearchSheetPresented,
                searchQuery: searchQuery,
                searchResults: searchResults,
                isSearching: isSearching
            )
        }
    }

    enum Action: Equatable {
        // Lifecycle
        case startHosting
        case stopHosting
        case exitTapped

        // Playback
        case playTapped
        case pauseTapped
        case skipTapped

        // Search
        case addSongTapped
        case searchQueryChanged(String)
        case searchResultsReceived([Song])
        case songSelected(Song)
        case dismissSearch

        // Authorization
        case requestMusicAuthorization

        // Network
        case multipeerEvent(MultipeerEvent)

        // Internal
        case _processIntent(GuestIntent, from: Peer)
        case _authorizationStatusUpdated(MusicAuthorization.Status)
        case _playbackStatusUpdated(PlaybackStatus)
        case _broadcastSnapshot
#if DEBUG
        case _debugSetNowPlaying
#endif
    }

    @Dependency(\.multipeerClient) private var multipeerClient
    @Dependency(\.musicKitClient) private var musicKitClient
    @Dependency(\.continuousClock) private var clock

    private enum CancelID {
        case multipeerEvents
        case playbackStatus
        case search
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
                        for await event in await multipeerClient.events() {
                            await send(.multipeerEvent(event))
                        }
                    }
                    .cancellable(id: CancelID.multipeerEvents, cancelInFlight: true)
                )
                effects.append(
                    .run { send in
                        for await status in musicKitClient.playbackStatus() {
                            await send(._playbackStatusUpdated(status))
                        }
                    }
                    .cancellable(id: CancelID.playbackStatus, cancelInFlight: true)
                )

            case .stopHosting:
                state.isHosting = false
                effects.append(.cancel(id: CancelID.multipeerEvents))
                effects.append(.cancel(id: CancelID.playbackStatus))
                effects.append(
                    .run { _ in
                        await multipeerClient.stop()
                    }
                )

            case .exitTapped:
                break

            case .playTapped:
                guard let song = state.nowPlaying else {
                    break
                }
                guard state.musicAuthorizationStatus == .authorized else {
                    effects.append(.send(.requestMusicAuthorization))
                    break
                }
                effects.append(
                    .run { _ in
                        try await musicKitClient.play(song)
                    }
                )

            case .pauseTapped:
                guard state.isPlaying else {
                    break
                }
                effects.append(
                    .run { _ in
                        await musicKitClient.pause()
                    }
                )

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

            case .addSongTapped:
                state.isSearchSheetPresented = true

            case let .searchQueryChanged(query):
                state.searchQuery = query
                guard !query.isEmpty else {
                    state.searchResults = []
                    state.isSearching = false
                    effects.append(.cancel(id: CancelID.search))
                    break
                }

                state.isSearching = true
                effects.append(
                    .run { send in
                        try await clock.sleep(for: .milliseconds(300))
                        let results = try await musicKitClient.search(query)
                        await send(.searchResultsReceived(results))
                    }
                    .cancellable(id: CancelID.search, cancelInFlight: true)
                )

            case let .searchResultsReceived(results):
                state.isSearching = false
                state.searchResults = results

            case let .songSelected(song):
                let isDuplicate = state.queue.contains(where: { $0.id == song.id }) || state.nowPlaying?.id == song.id
                state.isSearchSheetPresented = false
                state.searchQuery = ""
                state.searchResults = []
                state.isSearching = false

                guard !isDuplicate else {
                    effects.append(.cancel(id: CancelID.search))
                    break
                }

                let item = QueueItem(
                    id: song.id,
                    song: song,
                    addedBy: state.myPeer,
                    voters: []
                )
                state.queue.append(item)
                state.queue = sortedQueue(state.queue)
                needsBroadcast = true

            case .dismissSearch:
                state.isSearchSheetPresented = false
                state.searchQuery = ""
                state.searchResults = []
                state.isSearching = false
                effects.append(.cancel(id: CancelID.search))

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

            case let ._playbackStatusUpdated(status):
                let wasPlaying = state.playbackStatus.isPlaying
                state.playbackStatus = status
                state.isPlaying = status.isPlaying

                if wasPlaying,
                   !status.isPlaying,
                   status.duration > 0,
                   status.currentTime >= status.duration - 1,
                   state.nowPlaying != nil {
                    effects.append(.send(.skipTapped))
                }

            case ._broadcastSnapshot:
                let snapshot = HostSnapshot(
                    nowPlaying: state.nowPlaying,
                    queue: state.queue,
                    connectedPeers: state.connectedPeers
                )
                return .run { _ in
                    try? await multipeerClient.send(.stateUpdate(snapshot), nil)
                }

#if DEBUG
            case ._debugSetNowPlaying:
                state.nowPlaying = Song(
                    id: "debug-song",
                    title: "Debug Anthem",
                    artist: "Codex",
                    albumArtURL: nil,
                    duration: 180
                )
                state.isPlaying = false
                state.playbackStatus = .notPlaying
#endif
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
