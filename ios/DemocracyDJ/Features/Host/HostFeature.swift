import ComposableArchitecture
import Dependencies
import OSLog
import Shared
import struct MusicKit.MusicAuthorization
import UIKit

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
        var subscriptionStatus: SubscriptionStatus = .unknown
        var isSearchSheetPresented: Bool = false
        var searchQuery: String = ""
        var searchResults: [Song] = []
        var isSearching: Bool = false
        var myPeer: Peer
        var pendingRemovedSong: Song? // Transient: cleared after broadcast
        @Presents var alert: AlertState<Action.Alert>?

        var canPlay: Bool {
            musicAuthorizationStatus == .authorized && subscriptionStatus.canPlayCatalogContent
        }

        init(
            myPeer: Peer,
            nowPlaying: Song? = nil,
            queue: [QueueItem] = [],
            connectedPeers: [Peer] = [],
            isHosting: Bool = false,
            isPlaying: Bool = false,
            playbackStatus: PlaybackStatus = .notPlaying,
            musicAuthorizationStatus: MusicAuthorization.Status = .notDetermined,
            subscriptionStatus: SubscriptionStatus = .unknown,
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
            self.subscriptionStatus = subscriptionStatus
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
            subscriptionStatus: SubscriptionStatus = .unknown,
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
                subscriptionStatus: subscriptionStatus,
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

        // Queue
        case removeSongTapped(id: String)
        case removeSongFromQueue(id: String)

        // Authorization
        case requestMusicAuthorization

        // Alerts
        case alert(PresentationAction<Alert>)
        enum Alert: Equatable {
            case confirmRemoveSong(String)
            case dismiss
            case openSettings
        }

        // Network
        case multipeerEvent(MultipeerEvent)

        // Internal
        case _processIntent(GuestIntent, from: Peer)
        case _authorizationStatusUpdated(MusicAuthorization.Status)
        case _subscriptionStatusUpdated(SubscriptionStatus)
        case _playbackStatusUpdated(PlaybackStatus)
        case _playbackError(String)
        case _searchError(String)
        case _broadcastSnapshot
        case _heartbeat
        case _remoteCommand(RemoteCommand)
        case _seek(TimeInterval)
        case _hostingError(String)
#if DEBUG
        case _debugSetNowPlaying
#endif
    }

    @Dependency(\.multipeerClient) private var multipeerClient
    @Dependency(\.musicKitClient) private var musicKitClient
    @Dependency(\.nowPlayingClient) private var nowPlayingClient
    @Dependency(\.continuousClock) private var clock
    @Dependency(\.openURL) private var openURL

    private enum CancelID {
        case multipeerEvents
        case playbackStatus
        case search
        case remoteCommands
        case heartbeat
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
                    .run { _ in
                        await nowPlayingClient.configure()
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
                        for await command in nowPlayingClient.remoteCommands() {
                            await send(._remoteCommand(command))
                        }
                    }
                    .cancellable(id: CancelID.remoteCommands, cancelInFlight: true)
                )
                effects.append(
                    .run { send in
                        for await status in musicKitClient.playbackStatus() {
                            await send(._playbackStatusUpdated(status))
                        }
                    }
                    .cancellable(id: CancelID.playbackStatus, cancelInFlight: true)
                )
                effects.append(
                    .run { [clock] send in
                        while true {
                            try await clock.sleep(for: .seconds(2))
                            await send(._heartbeat)
                        }
                    }
                    .cancellable(id: CancelID.heartbeat, cancelInFlight: true)
                )
                effects.append(
                    .run { send in
                        let status = await musicKitClient.checkSubscription()
                        await send(._subscriptionStatusUpdated(status))
                    }
                )
                let initialNowPlaying = state.nowPlaying
                let initialIsPlaying = state.isPlaying
                let initialCurrentTime = state.playbackStatus.currentTime
                let initialDuration = state.playbackStatus.duration
                effects.append(
                    .run { _ in
                        await nowPlayingClient.updateNowPlaying(
                            initialNowPlaying,
                            initialIsPlaying,
                            initialCurrentTime,
                            initialDuration
                        )
                    }
                )

            case .stopHosting:
                state.isHosting = false
                effects.append(.cancel(id: CancelID.multipeerEvents))
                effects.append(.cancel(id: CancelID.playbackStatus))
                effects.append(.cancel(id: CancelID.remoteCommands))
                effects.append(.cancel(id: CancelID.heartbeat))
                effects.append(
                    .run { _ in
                        await multipeerClient.stop()
                    }
                )
                effects.append(
                    .run { _ in
                        await nowPlayingClient.updateNowPlaying(nil, false, 0, 0)
                    }
                )

            case .exitTapped:
                break

            case .playTapped:
                guard let song = state.nowPlaying else {
                    break
                }
                guard state.musicAuthorizationStatus == .authorized else {
                    state.alert = AlertState {
                        TextState("Music Access Required")
                    } actions: {
                        ButtonState(action: .openSettings) { TextState("Open Settings") }
                        ButtonState(role: .cancel, action: .dismiss) { TextState("Cancel") }
                    } message: {
                        TextState("Please authorize Apple Music to play songs.")
                    }
                    break
                }
                guard state.subscriptionStatus.canPlayCatalogContent else {
                    state.alert = AlertState {
                        TextState("Apple Music Subscription Required")
                    } actions: {
                        ButtonState(role: .cancel, action: .dismiss) { TextState("OK") }
                    } message: {
                        TextState("An active Apple Music subscription is required to play songs.")
                    }
                    break
                }
                effects.append(
                    .run { send in
                        do {
                            try await musicKitClient.play(song)
                        } catch {
                            await send(._playbackError(error.localizedDescription))
                        }
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
                        effects.append(
                            .run { _ in
                                await nowPlayingClient.updateNowPlaying(nil, false, 0, 0)
                            }
                        )
                    }
                } else {
                    state.nowPlaying = state.queue.removeFirst().song
                    needsBroadcast = true
                    let nowPlaying = state.nowPlaying
                    let isPlaying = state.isPlaying
                    let currentTime = state.playbackStatus.currentTime
                    let duration = state.playbackStatus.duration
                    effects.append(
                        .run { _ in
                            await nowPlayingClient.updateNowPlaying(
                                nowPlaying,
                                isPlaying,
                                currentTime,
                                duration
                            )
                        }
                    )
                }

            case .addSongTapped:
                state.isSearchSheetPresented = true

            case let .removeSongTapped(id):
                state.alert = AlertState {
                    TextState("Remove Song?")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmRemoveSong(id)) {
                        TextState("Remove")
                    }
                    ButtonState(role: .cancel, action: .dismiss) { TextState("Cancel") }
                } message: {
                    TextState("This will remove the song from the queue for everyone.")
                }

            case let .removeSongFromQueue(id):
                guard state.nowPlaying?.id != id else {
                    break
                }
                if let index = state.queue.firstIndex(where: { $0.id == id }) {
                    let removed = state.queue.remove(at: index)
                    state.pendingRemovedSong = removed.song
                    needsBroadcast = true
                }

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
                        do {
                            try await clock.sleep(for: .milliseconds(300))
                            let results = try await musicKitClient.search(query)
                            await send(.searchResultsReceived(results))
                        } catch is CancellationError {
                            return
                        } catch {
                            await send(._searchError(error.localizedDescription))
                        }
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

                case .peerLost:
                    break

                case let .startFailed(role, reason):
                    guard role == .advertiser else {
                        break
                    }
                    effects.append(.send(._hostingError(reason)))

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

            case let ._subscriptionStatusUpdated(status):
                state.subscriptionStatus = status

            case let ._playbackStatusUpdated(status):
                let wasPlaying = state.isPlaying
                state.playbackStatus = status
                state.isPlaying = status.isPlaying
                let nowPlaying = state.nowPlaying
                let isPlaying = state.isPlaying
                let currentTime = state.playbackStatus.currentTime
                let duration = state.playbackStatus.duration
                effects.append(
                    .run { _ in
                        await nowPlayingClient.updateNowPlaying(
                            nowPlaying,
                            isPlaying,
                            currentTime,
                            duration
                        )
                    }
                )

                let didFinishTrack = wasPlaying
                    && !status.isPlaying
                    && status.duration > 0
                    && status.currentTime >= status.duration - 1
                    && state.nowPlaying != nil

                if state.isPlaying != wasPlaying, !didFinishTrack {
                    needsBroadcast = true
                }

                if didFinishTrack {
                    effects.append(.send(.skipTapped))
                }

            case let ._remoteCommand(command):
                switch command {
                case .play:
                    effects.append(.send(.playTapped))
                case .pause:
                    effects.append(.send(.pauseTapped))
                case .togglePlayPause:
                    effects.append(.send(state.isPlaying ? .pauseTapped : .playTapped))
                case .nextTrack:
                    effects.append(.send(.skipTapped))
                case let .changePlaybackPosition(time):
                    effects.append(.send(._seek(time)))
                }

            case let ._seek(time):
                effects.append(
                    .run { _ in
                        await musicKitClient.seek(time)
                    }
                )

            case let ._playbackError(message):
                state.alert = AlertState {
                    TextState("Playback Error")
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) { TextState("OK") }
                } message: {
                    TextState(message)
                }

            case let ._searchError(message):
                state.isSearching = false
                state.alert = AlertState {
                    TextState("Search Error")
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) { TextState("OK") }
                } message: {
                    TextState(message)
                }

            case let ._hostingError(message):
                state.isHosting = false
                state.alert = AlertState {
                    TextState("Hosting Error")
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) { TextState("OK") }
                } message: {
                    TextState(message)
                }

            case ._broadcastSnapshot:
                let snapshot = HostSnapshot(
                    nowPlaying: state.nowPlaying,
                    queue: state.queue,
                    connectedPeers: state.connectedPeers,
                    isPlaying: state.isPlaying,
                    removedSong: state.pendingRemovedSong
                )
                state.pendingRemovedSong = nil // Clear after capturing in snapshot
                return .run { _ in
                    do {
                        try await multipeerClient.send(.stateUpdate(snapshot), nil)
                    } catch {
                        Logger.host.error("Multipeer send failed: \(error)")
                    }
                }

            case ._heartbeat:
                guard state.isHosting, !state.connectedPeers.isEmpty else {
                    return .none
                }
                return .send(._broadcastSnapshot)

            case .alert(.presented(.openSettings)):
                state.alert = nil
                return .run { _ in
                    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }
                    await openURL(settingsURL)
                }

            case let .alert(.presented(.confirmRemoveSong(id))):
                state.alert = nil
                return .send(.removeSongFromQueue(id: id))

            case .alert(.presented(.dismiss)):
                state.alert = nil

            case .alert(.dismiss):
                state.alert = nil

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
                let nowPlaying = state.nowPlaying
                let isPlaying = state.isPlaying
                let currentTime = state.playbackStatus.currentTime
                let duration = state.playbackStatus.duration
                effects.append(
                    .run { _ in
                        await nowPlayingClient.updateNowPlaying(
                            nowPlaying,
                            isPlaying,
                            currentTime,
                            duration
                        )
                    }
                )
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
        .ifLet(\.$alert, action: \.alert)
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
