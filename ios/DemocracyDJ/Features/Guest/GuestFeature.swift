import ComposableArchitecture
import Dependencies
import Foundation
import Shared
import struct MusicKit.MusicAuthorization
import UIKit

@Reducer
struct GuestFeature {
    struct ToastMessage: Equatable, Identifiable {
        let id: UUID
        let text: String
        let songID: String
    }

    @ObservableState
    struct State: Equatable {
        /// Local peer identity owned by this reducer.
        /// Created on startBrowsing; never inferred from network events.
        var myPeer: Peer?

        var connectionStatus: ConnectionStatus = .disconnected
        var hostSnapshot: HostSnapshot?
        var pendingVotes: Set<String> = []
        var availableHosts: IdentifiedArrayOf<Peer> = []
        var showSearchSheet: Bool = false
        var searchQuery: String = ""
        var searchResults: [Song] = []
        var isSearching: Bool = false
        var searchError: String?
        var recommendations: [RecommendationSection] = []
        var isLoadingRecommendations: Bool = false
        var recommendationsError: String?
        var musicAuthorizationStatus: MusicAuthorization.Status = .notDetermined
        var lastHostActivityAt: Date?
        var toastQueue: [ToastMessage] = []
        @Presents var alert: AlertState<Action.Alert>?

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
        case exitTapped

        // MARK: - User Actions
        case voteTapped(songID: String)
        case suggestSongTapped(Song)
        case searchButtonTapped
        case searchQueryChanged(String)
        case searchResultsReceived([Song])
        case loadRecommendations
        case _recommendationsReceived([RecommendationSection])
        case _recommendationsError(String)
        case songSelected(Song)
        case dismissSearch
        case _authorizationStatusUpdated(MusicAuthorization.Status)
        case alert(PresentationAction<Alert>)

        enum Alert: Equatable {
            case openSettings
            case dismiss
        }

        // MARK: - Network
        case multipeerEvent(MultipeerEvent)

        // MARK: - Internal
        case _snapshotReceived(HostSnapshot)
        case _connectionFailed(String)
        case _connectionTimeout
        case _checkHostActivity
        case _searchError(String)
        case _showToast(ToastMessage)
        case _dismissToast(id: UUID)
        case _toastTimerFired(id: UUID)

#if DEBUG
        case debugLoadSample
        case debugLoadRecommendations
#endif
    }

    @Dependency(\.multipeerClient) var multipeerClient
    @Dependency(\.musicKitClient) var musicKitClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.timingConfig) var timingConfig
    @Dependency(\.date) var date
    @Dependency(\.uuid) var uuid
    @Dependency(\.openURL) var openURL

    private enum CancelID: Hashable {
        case multipeerEvents
        case search
        case recommendations
        case connectionTimeout
        case activityTimeout
        case toastTimer(UUID)
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
                state.lastHostActivityAt = nil

                return .run { send in
                    await multipeerClient.startBrowsing(displayName)
                    for await event in await multipeerClient.events() {
                        await send(.multipeerEvent(event))
                    }
                }
                .cancellable(id: CancelID.multipeerEvents, cancelInFlight: true)

            case .stopBrowsing:
                // Cancel all toast timers before clearing the queue
                let toastCancels = state.toastQueue.map { toast in
                    Effect<Action>.cancel(id: CancelID.toastTimer(toast.id))
                }

                state.connectionStatus = .disconnected
                state.availableHosts.removeAll()
                state.hostSnapshot = nil
                state.pendingVotes.removeAll()
                state.showSearchSheet = false
                state.searchQuery = ""
                state.searchResults = []
                state.isSearching = false
                state.searchError = nil
                state.recommendations = []
                state.isLoadingRecommendations = false
                state.recommendationsError = nil
                state.lastHostActivityAt = nil
                state.toastQueue = []
                state.alert = nil

                return .merge(
                    [
                        .run { _ in
                            await multipeerClient.stop()
                        },
                        .cancel(id: CancelID.multipeerEvents),
                        .cancel(id: CancelID.search),
                        .cancel(id: CancelID.recommendations),
                        .cancel(id: CancelID.connectionTimeout),
                        .cancel(id: CancelID.activityTimeout)
                    ] + toastCancels
                )

            case .exitTapped:
                return .none

            case let .connectToHost(host):
                state.connectionStatus = .connecting(host: host)

                return .merge(
                    .run { send in
                        do {
                            try await multipeerClient.invite(host)
                        } catch {
                            await send(._connectionFailed("Connection failed"))
                        }
                    },
                    .run { [clock, timingConfig] send in
                        try await clock.sleep(for: timingConfig.connectionTimeout)
                        await send(._connectionTimeout)
                    }
                    .cancellable(id: CancelID.connectionTimeout, cancelInFlight: true)
                )

            case let ._connectionFailed(reason):
                state.connectionStatus = .failed(reason: reason)
                return .cancel(id: CancelID.connectionTimeout)

            case ._connectionTimeout:
                if case .connecting = state.connectionStatus {
                    state.connectionStatus = .failed(reason: "Connection timed out")
                }
                return .none

            // MARK: - User Actions

            case let .voteTapped(songID):
                guard case let .connected(host) = state.connectionStatus else {
                    return .none
                }

                // Optimistic UI: record vote immediately
                state.pendingVotes.insert(songID)

                return .run { _ in
                    do {
                        let intent = GuestIntent.vote(songID: songID)
                        let message = MeshMessage.intent(intent)
                        try await multipeerClient.send(message, host)
                    } catch {
                        // Ignore send failures for now; host may be unavailable.
                    }
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

            case .searchButtonTapped:
                let currentStatus = musicKitClient.currentAuthorizationStatus()
                state.musicAuthorizationStatus = currentStatus

                switch currentStatus {
                case .authorized:
                    state.showSearchSheet = true
                    state.searchError = nil
                    return .send(.loadRecommendations)

                case .notDetermined:
                    return .run { send in
                        let status = await musicKitClient.requestAuthorization()
                        await send(._authorizationStatusUpdated(status))
                    }

                case .denied, .restricted:
                    state.alert = AlertState {
                        TextState("Music Access Required")
                    } actions: {
                        ButtonState(action: .openSettings) { TextState("Open Settings") }
                        ButtonState(role: .cancel, action: .dismiss) { TextState("Cancel") }
                    } message: {
                        TextState("Please authorize Apple Music to search for songs.")
                    }
                    return .none

                @unknown default:
                    return .none
                }

            case let .searchQueryChanged(query):
                state.searchQuery = query
                state.searchError = nil

                guard query.count >= 2 else {
                    state.searchResults = []
                    state.isSearching = false
                    return .cancel(id: CancelID.search)
                }

                state.isSearching = true
                return .run { [clock, timingConfig] send in
                    do {
                        try await clock.sleep(for: timingConfig.searchDebounce)
                        let results = try await musicKitClient.search(query)
                        await send(.searchResultsReceived(results))
                    } catch is CancellationError {
                        return
                    } catch {
                        await send(._searchError(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.search, cancelInFlight: true)

            case let .searchResultsReceived(results):
                state.isSearching = false
                state.searchResults = results
                return .none

            case .loadRecommendations:
                guard !state.isLoadingRecommendations else {
                    return .none
                }

                guard state.recommendations.isEmpty else {
                    return .none
                }

                state.isLoadingRecommendations = true
                state.recommendationsError = nil

                return .run { send in
                    do {
                        let sections = try await musicKitClient.recommendations()
                        await send(._recommendationsReceived(sections))
                    } catch {
                        await send(._recommendationsError(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.recommendations, cancelInFlight: true)

            case let ._recommendationsReceived(sections):
                state.isLoadingRecommendations = false
                state.recommendations = sections
                state.recommendationsError = nil
                return .none

            case let ._recommendationsError(message):
                state.isLoadingRecommendations = false
                state.recommendationsError = message
                return .none

            case let .songSelected(song):
                state.showSearchSheet = false
                state.searchQuery = ""
                state.searchResults = []
                state.isSearching = false
                state.searchError = nil
                return .send(.suggestSongTapped(song))

            case .dismissSearch:
                state.showSearchSheet = false
                state.searchQuery = ""
                state.searchResults = []
                state.isSearching = false
                state.searchError = nil
                return .cancel(id: CancelID.search)

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
                        state.lastHostActivityAt = date.now
                        return .merge(
                            .cancel(id: CancelID.connectionTimeout),
                            .run { [clock, timingConfig] send in
                                while true {
                                    try await clock.sleep(for: timingConfig.activityCheckInterval)
                                    await send(._checkHostActivity)
                                }
                            }
                            .cancellable(id: CancelID.activityTimeout, cancelInFlight: true)
                        )
                    }
                    return .none

                case .peerDisconnected:
                    state.connectionStatus = .disconnected
                    state.hostSnapshot = nil
                    state.pendingVotes.removeAll()
                    state.lastHostActivityAt = nil
                    return .cancel(id: CancelID.activityTimeout)

                case let .peerLost(peer):
                    state.availableHosts.remove(id: peer.id)
                    if case let .connecting(host) = state.connectionStatus, host.id == peer.id {
                        state.connectionStatus = .failed(reason: "Host no longer available")
                        return .cancel(id: CancelID.connectionTimeout)
                    }
                    return .none

                case let .startFailed(role, reason):
                    guard role == .browser else {
                        return .none
                    }
                    state.connectionStatus = .failed(reason: "Unable to search: \(reason)")
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
                state.lastHostActivityAt = date.now

                // Handle removed song notification
                if let removedSong = snapshot.removedSong,
                   !state.toastQueue.contains(where: { $0.songID == removedSong.id }) {
                    let toast = ToastMessage(
                        id: uuid(),
                        text: "\"\(removedSong.title)\" was removed",
                        songID: removedSong.id
                    )
                    return .send(._showToast(toast))
                }
                return .none

            case let ._searchError(message):
                state.isSearching = false
                state.searchError = message
                return .none

            case ._checkHostActivity:
                guard case .connected = state.connectionStatus else {
                    return .cancel(id: CancelID.activityTimeout)
                }

                guard let lastActivity = state.lastHostActivityAt else {
                    return .none
                }

                let elapsed = date.now.timeIntervalSince(lastActivity)
                if elapsed > timingConfig.inactivityTimeout {
                    state.connectionStatus = .disconnected
                    state.hostSnapshot = nil
                    state.pendingVotes.removeAll()
                    state.lastHostActivityAt = nil
                    return .cancel(id: CancelID.activityTimeout)
                }

                return .none

            case let ._authorizationStatusUpdated(status):
                state.musicAuthorizationStatus = status

                if status == .authorized {
                    state.showSearchSheet = true
                    state.searchError = nil
                    return .send(.loadRecommendations)
                }

                state.alert = AlertState {
                    TextState("Music Access Required")
                } actions: {
                    ButtonState(action: .openSettings) { TextState("Open Settings") }
                    ButtonState(role: .cancel, action: .dismiss) { TextState("Cancel") }
                } message: {
                    TextState("Please authorize Apple Music to search for songs.")
                }
                return .none

            case .alert(.presented(.openSettings)):
                state.alert = nil
                return .run { _ in
                    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }
                    await openURL(settingsURL)
                }

            case .alert(.presented(.dismiss)):
                state.alert = nil
                return .none

            case .alert(.dismiss):
                state.alert = nil
                return .none

            // MARK: - Toast

            case let ._showToast(toast):
                state.toastQueue.append(toast)

                return .run { [clock, timingConfig] send in
                    try await clock.sleep(for: timingConfig.toastDismissal)
                    await send(._toastTimerFired(id: toast.id))
                }
                .cancellable(id: CancelID.toastTimer(toast.id))

            case let ._dismissToast(id):
                state.toastQueue.removeAll { $0.id == id }
                return .cancel(id: CancelID.toastTimer(id))

            case let ._toastTimerFired(id):
                state.toastQueue.removeAll { $0.id == id }
                return .none

#if DEBUG
            case .debugLoadSample:
                let host = Peer(name: "Debug Host")
                state.myPeer = state.myPeer ?? Peer(id: uuid().uuidString, name: "Guest")
                state.connectionStatus = .connected(host: host)
                state.hostSnapshot = Self.debugSnapshot
                state.pendingVotes = ["song-debug-3"]
                return .none

            case .debugLoadRecommendations:
                state.isLoadingRecommendations = false
                state.recommendationsError = nil
                state.recommendations = .previewRecommendations
                return .none
#endif
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

#if DEBUG
private extension GuestFeature {
    static var debugSnapshot: HostSnapshot {
        HostSnapshot(
            nowPlaying: Song(
                id: "song-debug-1",
                title: "Starlight",
                artist: "Muse",
                albumArtURL: nil,
                duration: 240
            ),
            queue: [
                QueueItem(
                    id: "song-debug-2",
                    song: Song(
                        id: "song-debug-2",
                        title: "Midnight City",
                        artist: "M83",
                        albumArtURL: nil,
                        duration: 260
                    ),
                    addedBy: Peer(name: "Alex"),
                    voters: ["guest"]
                ),
                QueueItem(
                    id: "song-debug-3",
                    song: Song(
                        id: "song-debug-3",
                        title: "Electric Feel",
                        artist: "MGMT",
                        albumArtURL: nil,
                        duration: 230
                    ),
                    addedBy: Peer(name: "Sam"),
                    voters: []
                )
            ],
            connectedPeers: [Peer(name: "Alex"), Peer(name: "Sam")],
            isPlaying: true
        )
    }
}
#endif
