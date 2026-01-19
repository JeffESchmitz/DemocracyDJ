import ComposableArchitecture
import ConcurrencyExtras
import Foundation
import Shared
import Testing
@testable import DemocracyDJ

@MainActor
@Suite("GuestFeature")
struct GuestFeatureTests {
    @Test func startBrowsingCreatesLocalPeer() async {
        let recorder = GuestStartRecorder()
        let store = TestStore(initialState: GuestFeature.State()) {
            GuestFeature()
        } withDependencies: {
            $0.multipeerClient = .mock(
                events: { AsyncStream { $0.finish() } },
                onStartBrowsing: { displayName in
                    await recorder.record(name: displayName)
                }
            )
            $0.uuid = .incrementing
        }

        await store.send(.startBrowsing(displayName: "Guest")) {
            $0.myPeer = Peer(id: UUID(0).uuidString, name: "Guest")
            $0.connectionStatus = .browsing
            $0.availableHosts = []
            $0.hostSnapshot = nil
            $0.pendingVotes = []
        }

        #expect(store.state.connectionStatus == .browsing)
        #expect(store.state.availableHosts.isEmpty)
        #expect(store.state.hostSnapshot == nil)
        #expect(store.state.pendingVotes.isEmpty)
        #expect(store.state.myPeer?.name == "Guest")

        let startedName = await recorder.name
        #expect(startedName == "Guest")

        await store.finish()
    }

    @Test func voteTappedSendsIntentAndTracksPending() async {
        let host = Peer(id: "host", name: "Host")
        let recorder = GuestSendRecorder()
        let songID = "song-1"

        let store = TestStore(initialState: GuestFeature.State(
            myPeer: Peer(id: "guest", name: "Guest"),
            connectionStatus: .connected(host: host)
        )) {
            GuestFeature()
        } withDependencies: {
            $0.multipeerClient = .mock(
                onSend: { message, target in
                    await recorder.record(message: message, target: target)
                }
            )
        }

        await store.send(.voteTapped(songID: songID)) {
            $0.pendingVotes = [songID]
        }

        await recorder.waitForCount(1)
        let record = await recorder.last
        #expect(record?.message == .intent(.vote(songID: songID)))
        #expect(record?.target == host)
    }

    @Test func snapshotReceivedClearsPendingVotes() async {
        let clock = TestClock()
        let now = LockIsolated(Date(timeIntervalSince1970: 0))
        let snapshot = HostSnapshot(nowPlaying: nil, queue: [], connectedPeers: [])
        let store = TestStore(initialState: GuestFeature.State(
            myPeer: Peer(id: "guest", name: "Guest"),
            hostSnapshot: nil,
            pendingVotes: ["song-1"]
        )) {
            GuestFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.date = .init { now.withValue { $0 } }
        }

        let expected = now.withValue { $0 }
        await store.send(GuestFeature.Action._snapshotReceived(snapshot)) {
            $0.hostSnapshot = snapshot
            $0.pendingVotes = []
            $0.lastHostActivityAt = expected
        }
    }

    @Test func peerDiscoveryUpdatesAvailableHosts() async {
        let host = Peer(id: "host", name: "Host")
        let store = TestStore(initialState: GuestFeature.State()) {
            GuestFeature()
        }

        await store.send(.multipeerEvent(.peerDiscovered(host))) {
            $0.availableHosts.append(host)
        }

        await store.send(.multipeerEvent(.peerDiscovered(host)))
        #expect(store.state.availableHosts.count == 1)
    }

    @Test func connectToHostInvites() async {
        let host = Peer(id: "host", name: "Host")
        let recorder = InviteRecorder()
        let clock = TestClock()

        let store = TestStore(initialState: GuestFeature.State()) {
            GuestFeature()
        } withDependencies: {
            $0.multipeerClient = .mock(
                onInvite: { peer in
                    await recorder.record(peer: peer)
                }
            )
            $0.continuousClock = clock
        }

        await store.send(.connectToHost(host)) {
            $0.connectionStatus = .connecting(host: host)
        }

        await recorder.waitForCount(1)
        let last = await recorder.last
        #expect(last == host)

        await store.send(.stopBrowsing) {
            $0.connectionStatus = .disconnected
        }
    }

    @Test func peerLostRemovesFromAvailableHosts() async {
        let host = Peer(id: "host", name: "Host")

        let store = TestStore(initialState: GuestFeature.State(
            availableHosts: [host]
        )) {
            GuestFeature()
        }

        await store.send(.multipeerEvent(.peerLost(host))) {
            $0.availableHosts = []
        }
    }

    @Test func peerLostWhileConnectingFailsConnection() async {
        let host = Peer(id: "host", name: "Host")

        let store = TestStore(initialState: GuestFeature.State(
            connectionStatus: .connecting(host: host),
            availableHosts: [host]
        )) {
            GuestFeature()
        }

        await store.send(.multipeerEvent(.peerLost(host))) {
            $0.availableHosts = []
            $0.connectionStatus = .failed(reason: "Host no longer available")
        }
    }

    @Test func browserStartFailedShowsFailure() async {
        let store = TestStore(initialState: GuestFeature.State()) {
            GuestFeature()
        }

        await store.send(.multipeerEvent(.startFailed(role: .browser, reason: "No permission"))) {
            $0.connectionStatus = .failed(reason: "Unable to search: No permission")
        }
    }

    @Test func connectionTimeoutRevertsToFailed() async {
        let clock = TestClock()
        let host = Peer(id: "host", name: "Host")

        let store = TestStore(initialState: GuestFeature.State()) {
            GuestFeature()
        } withDependencies: {
            $0.multipeerClient = .mock()
            $0.continuousClock = clock
        }

        await store.send(.connectToHost(host)) {
            $0.connectionStatus = .connecting(host: host)
        }

        await clock.advance(by: .seconds(15))

        await store.receive(\._connectionTimeout) {
            $0.connectionStatus = .failed(reason: "Connection timed out")
        }
    }

    @Test func activityTimeoutDisconnectsWhenNoSnapshots() async {
        let clock = TestClock()
        let host = Peer(id: "host", name: "Host")
        let now = LockIsolated(Date(timeIntervalSince1970: 0))
        let config = TimingConfig.testValue

        let store = TestStore(initialState: GuestFeature.State(
            connectionStatus: .connecting(host: host)
        )) {
            GuestFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.timingConfig = config
            $0.date = .init { now.withValue { $0 } }
        }

        let expected = now.withValue { $0 }
        await store.send(.multipeerEvent(.peerConnected(host))) {
            $0.connectionStatus = .connected(host: host)
            $0.availableHosts = []
            $0.lastHostActivityAt = expected
        }

        now.withValue { $0 = $0.addingTimeInterval(1) }
        await clock.advance(by: .seconds(1))

        await store.receive(\._checkHostActivity) {
            $0.connectionStatus = .disconnected
            $0.hostSnapshot = nil
            $0.pendingVotes = []
            $0.lastHostActivityAt = nil
        }
    }

    @Test func peerConnectedCancelsTimeout() async {
        let clock = TestClock()
        let host = Peer(id: "host", name: "Host")
        let now = LockIsolated(Date(timeIntervalSince1970: 0))

        let store = TestStore(initialState: GuestFeature.State(
            availableHosts: [host]
        )) {
            GuestFeature()
        } withDependencies: {
            $0.multipeerClient = .mock()
            $0.continuousClock = clock
            var config = TimingConfig.testValue
            config.inactivityTimeout = 100
            config.activityCheckInterval = .seconds(100)
            $0.timingConfig = config
            $0.date = .init { now.withValue { $0 } }
        }

        await store.send(.connectToHost(host)) {
            $0.connectionStatus = .connecting(host: host)
        }

        let expected = now.withValue { $0 }
        await store.send(.multipeerEvent(.peerConnected(host))) {
            $0.connectionStatus = .connected(host: host)
            $0.availableHosts = []
            $0.lastHostActivityAt = expected
        }

        await clock.advance(by: .seconds(15))
        await store.send(.stopBrowsing) {
            $0.connectionStatus = .disconnected
            $0.availableHosts = []
            $0.hostSnapshot = nil
            $0.pendingVotes = []
            $0.showSearchSheet = false
            $0.searchQuery = ""
            $0.searchResults = []
            $0.isSearching = false
            $0.searchError = nil
            $0.recommendations = []
            $0.isLoadingRecommendations = false
            $0.recommendationsError = nil
            $0.lastHostActivityAt = nil
        }
    }

    @Test func stopBrowsingCancelsConnectionTimeout() async {
        let clock = TestClock()
        let host = Peer(id: "host", name: "Host")

        let store = TestStore(initialState: GuestFeature.State()) {
            GuestFeature()
        } withDependencies: {
            $0.multipeerClient = .mock()
            $0.continuousClock = clock
        }

        await store.send(.connectToHost(host)) {
            $0.connectionStatus = .connecting(host: host)
        }

        await store.send(.stopBrowsing) {
            $0.connectionStatus = .disconnected
        }

        await clock.advance(by: .seconds(15))
        await store.finish()
    }

    @Test func exitTappedIsNoOp() async {
        let store = TestStore(initialState: GuestFeature.State()) {
            GuestFeature()
        }

        await store.send(.exitTapped)
    }

    @Test func stopBrowsingCancelsEventStream() async {
        var continuation: AsyncStream<MultipeerEvent>.Continuation?
        let stream = AsyncStream<MultipeerEvent> { streamContinuation in
            continuation = streamContinuation
        }
        let stopRecorder = GuestStopRecorder()

        let store = TestStore(initialState: GuestFeature.State()) {
            GuestFeature()
        } withDependencies: {
            $0.multipeerClient = .mock(
                events: { stream },
                onStop: { await stopRecorder.record() }
            )
            $0.uuid = .incrementing
        }

        await store.send(.startBrowsing(displayName: "Guest")) {
            $0.myPeer = Peer(id: UUID(0).uuidString, name: "Guest")
            $0.connectionStatus = .browsing
        }

        await store.send(.stopBrowsing) {
            $0.connectionStatus = .disconnected
        }

        #expect(await stopRecorder.called)

        continuation?.yield(.peerDiscovered(Peer(id: "late", name: "Late")))
        await store.finish()
    }

    @Test func stopBrowsingClearsState() async {
        let store = TestStore(initialState: GuestFeature.State(
            myPeer: Peer(id: "guest", name: "Guest"),
            connectionStatus: .connected(host: Peer(id: "host", name: "Host")),
            hostSnapshot: HostSnapshot(nowPlaying: nil, queue: [], connectedPeers: []),
            pendingVotes: ["song-1"],
            availableHosts: [Peer(id: "host", name: "Host")],
            showSearchSheet: true,
            searchQuery: "test",
            searchResults: [Song.previewSong],
            isSearching: true,
            searchError: "error",
            recommendations: [.previewSection1],
            isLoadingRecommendations: true,
            recommendationsError: "error"
        )) {
            GuestFeature()
        } withDependencies: {
            $0.multipeerClient = .mock()
        }

        await store.send(.stopBrowsing) {
            $0.connectionStatus = .disconnected
            $0.availableHosts = []
            $0.hostSnapshot = nil
            $0.pendingVotes = []
            $0.showSearchSheet = false
            $0.searchQuery = ""
            $0.searchResults = []
            $0.isSearching = false
            $0.searchError = nil
            $0.recommendations = []
            $0.isLoadingRecommendations = false
            $0.recommendationsError = nil
        }
    }

    @Test func startBrowsingTwiceCancelsPreviousStream() async {
        let terminationRecorder = TerminationRecorder()
        let firstStream = AsyncStream<MultipeerEvent> { continuation in
            continuation.onTermination = { _ in
                Task {
                    await terminationRecorder.record()
                }
            }
        }
        let secondStream = AsyncStream<MultipeerEvent> { _ in }
        let recorder = GuestStartRecorder()
        let counter = EventsStreamCounter(
            first: firstStream,
            second: secondStream
        )

        let store = TestStore(initialState: GuestFeature.State()) {
            GuestFeature()
        } withDependencies: {
            $0.multipeerClient = .mock(
                events: {
                    await counter.nextStream()
                },
                onStartBrowsing: { displayName in
                    await recorder.record(name: displayName)
                }
            )
            $0.uuid = .incrementing
        }

        await store.send(.startBrowsing(displayName: "Guest")) {
            $0.myPeer = Peer(id: UUID(0).uuidString, name: "Guest")
            $0.connectionStatus = .browsing
        }

        await store.send(.startBrowsing(displayName: "Guest Again")) {
            $0.myPeer = Peer(id: UUID(1).uuidString, name: "Guest Again")
            $0.connectionStatus = .browsing
        }

        await terminationRecorder.waitForCount(1)

        await store.send(.stopBrowsing) {
            $0.connectionStatus = .disconnected
            $0.availableHosts = []
            $0.hostSnapshot = nil
            $0.pendingVotes = []
        }

        await store.finish()
    }

    @Test func searchQueryDebounced() async {
        let clock = TestClock()
        let song = Song.previewSong

        let store = TestStore(initialState: GuestFeature.State()) {
            GuestFeature()
        } withDependencies: {
            $0.musicKitClient = .mock(search: { _ in [song] })
            $0.continuousClock = clock
        }

        await store.send(.searchQueryChanged("ha")) {
            $0.searchQuery = "ha"
            $0.isSearching = true
            $0.searchError = nil
        }

        await clock.advance(by: .milliseconds(300))

        await store.receive(\.searchResultsReceived) {
            $0.searchResults = [song]
            $0.isSearching = false
        }
    }

    @Test func loadRecommendationsFetchesFromMusicKit() async {
        let sections = [RecommendationSection.previewSection1]

        let store = TestStore(initialState: GuestFeature.State()) {
            GuestFeature()
        } withDependencies: {
            $0.musicKitClient = .mock(recommendations: { sections })
        }

        await store.send(.loadRecommendations) {
            $0.isLoadingRecommendations = true
            $0.recommendationsError = nil
        }

        await store.receive(\._recommendationsReceived) {
            $0.isLoadingRecommendations = false
            $0.recommendations = sections
            $0.recommendationsError = nil
        }
    }

    @Test func loadRecommendationsSkipsIfAlreadyLoaded() async {
        let store = TestStore(initialState: GuestFeature.State(
            recommendations: [.previewSection1]
        )) {
            GuestFeature()
        }

        await store.send(.loadRecommendations)
    }

    @Test func loadRecommendationsSkipsIfLoading() async {
        let store = TestStore(initialState: GuestFeature.State(
            isLoadingRecommendations: true
        )) {
            GuestFeature()
        }

        await store.send(.loadRecommendations)
    }

    @Test func recommendationsErrorHandledGracefully() async {
        let store = TestStore(initialState: GuestFeature.State()) {
            GuestFeature()
        } withDependencies: {
            $0.musicKitClient = .mock(recommendations: {
                throw GuestTestMusicKitError.recommendationsFailed
            })
        }

        await store.send(.loadRecommendations) {
            $0.isLoadingRecommendations = true
            $0.recommendationsError = nil
        }

        await store.receive(\._recommendationsError) {
            $0.isLoadingRecommendations = false
            $0.recommendationsError = "Recommendations failed"
        }
    }

    @Test func searchButtonTappedTriggersRecommendationsLoad() async {
        let sections = [RecommendationSection.previewSection1]

        let store = TestStore(initialState: GuestFeature.State()) {
            GuestFeature()
        } withDependencies: {
            $0.musicKitClient = .mock(
                currentAuthorizationStatus: { .authorized },
                recommendations: { sections }
            )
        }

        await store.send(.searchButtonTapped) {
            $0.showSearchSheet = true
            $0.searchError = nil
            $0.musicAuthorizationStatus = .authorized
        }

        await store.receive(\.loadRecommendations) {
            $0.isLoadingRecommendations = true
            $0.recommendationsError = nil
        }

        await store.receive(\._recommendationsReceived) {
            $0.isLoadingRecommendations = false
            $0.recommendations = sections
            $0.recommendationsError = nil
        }
    }

    @Test func songSelectedSendsSuggestAndClosesSheet() async {
        let host = Peer(id: "host", name: "Host")
        let recorder = GuestSendRecorder()
        let song = Song.previewSong

        let store = TestStore(initialState: GuestFeature.State(
            myPeer: Peer(id: "guest", name: "Guest"),
            connectionStatus: .connected(host: host),
            showSearchSheet: true,
            searchQuery: "ha",
            searchResults: [song],
            isSearching: false
        )) {
            GuestFeature()
        } withDependencies: {
            $0.multipeerClient = .mock(
                onSend: { message, target in
                    await recorder.record(message: message, target: target)
                }
            )
        }

        await store.send(.songSelected(song)) {
            $0.showSearchSheet = false
            $0.searchQuery = ""
            $0.searchResults = []
            $0.isSearching = false
            $0.searchError = nil
        }

        await store.receive(\.suggestSongTapped)

        await recorder.waitForCount(1)
        let record = await recorder.last
        #expect(record?.message == .intent(.suggestSong(song)))
        #expect(record?.target == host)
    }

    @Test func searchErrorShowsError() async {
        let clock = TestClock()

        let store = TestStore(initialState: GuestFeature.State()) {
            GuestFeature()
        } withDependencies: {
            $0.musicKitClient = .mock(search: { _ in throw GuestTestMusicKitError.searchFailed })
            $0.continuousClock = clock
        }

        await store.send(.searchQueryChanged("ha")) {
            $0.searchQuery = "ha"
            $0.isSearching = true
            $0.searchError = nil
        }

        await clock.advance(by: .milliseconds(300))

        await store.receive(\._searchError) {
            $0.isSearching = false
            $0.searchError = "Search failed"
        }
    }

    @Test func dismissSearchCancelsAndClearsState() async {
        let clock = TestClock()
        let recorder = GuestSearchRecorder()
        let song = Song.previewSong

        let store = TestStore(initialState: GuestFeature.State(
            showSearchSheet: true
        )) {
            GuestFeature()
        } withDependencies: {
            $0.musicKitClient = .mock(search: { query in
                await recorder.record(query)
                return [song]
            })
            $0.continuousClock = clock
        }

        await store.send(.searchQueryChanged("ha")) {
            $0.searchQuery = "ha"
            $0.isSearching = true
            $0.searchError = nil
        }

        await store.send(.dismissSearch) {
            $0.showSearchSheet = false
            $0.searchQuery = ""
            $0.searchResults = []
            $0.isSearching = false
            $0.searchError = nil
        }

        await clock.advance(by: .milliseconds(300))
        #expect(await recorder.count == 0)
    }

    // MARK: - Toast Tests

    @Test func snapshotWithRemovedSongShowsToast() async {
        let clock = TestClock()
        let now = LockIsolated(Date(timeIntervalSince1970: 0))
        let store = TestStore(initialState: GuestFeature.State(
            connectionStatus: .connected(host: Peer(id: "host", name: "Host"))
        )) {
            GuestFeature()
        } withDependencies: {
            $0.uuid = .incrementing
            $0.continuousClock = clock
            $0.date = .init { now.withValue { $0 } }
        }

        let song = Song(id: "song-1", title: "Hotel California", artist: "Eagles", albumArtURL: nil, duration: 200)
        let snapshot = HostSnapshot(nowPlaying: nil, queue: [], connectedPeers: [], removedSong: song)

        let expected = now.withValue { $0 }
        await store.send(._snapshotReceived(snapshot)) {
            $0.hostSnapshot = snapshot
            $0.lastHostActivityAt = expected
        }

        await store.receive(\._showToast) {
            $0.toastQueue = [GuestFeature.ToastMessage(
                id: UUID(0),
                text: "\"Hotel California\" was removed",
                songID: "song-1"
            )]
        }

        await store.send(.stopBrowsing) {
            $0.connectionStatus = .disconnected
            $0.hostSnapshot = nil
            $0.toastQueue = []
            $0.lastHostActivityAt = nil
        }
    }

    @Test func toastAutoDismissesAfterDelay() async {
        let clock = TestClock()
        let toast = GuestFeature.ToastMessage(id: UUID(0), text: "Test", songID: "1")

        let store = TestStore(initialState: GuestFeature.State()) {
            GuestFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.uuid = .incrementing
        }

        await store.send(._showToast(toast)) {
            $0.toastQueue = [toast]
        }

        await clock.advance(by: .seconds(3))

        await store.receive(\._toastTimerFired) {
            $0.toastQueue = []
        }
    }

    @Test func duplicateSnapshotDoesNotDuplicateToast() async {
        let now = LockIsolated(Date(timeIntervalSince1970: 0))
        let song = Song(id: "song-1", title: "Test", artist: "Artist", albumArtURL: nil, duration: 200)
        let toast = GuestFeature.ToastMessage(id: UUID(0), text: "Test", songID: "song-1")

        let store = TestStore(initialState: GuestFeature.State(
            connectionStatus: .connected(host: Peer(id: "host", name: "Host")),
            toastQueue: [toast]
        )) {
            GuestFeature()
        } withDependencies: {
            $0.date = .init { now.withValue { $0 } }
        }

        let snapshot = HostSnapshot(nowPlaying: nil, queue: [], connectedPeers: [], removedSong: song)

        let expected = now.withValue { $0 }
        await store.send(._snapshotReceived(snapshot)) {
            $0.hostSnapshot = snapshot
            $0.lastHostActivityAt = expected
        }
    }

    @Test func manualDismissCancelsTimer() async {
        let clock = TestClock()
        let toast = GuestFeature.ToastMessage(id: UUID(0), text: "Test", songID: "1")

        let store = TestStore(initialState: GuestFeature.State(
            toastQueue: [toast]
        )) {
            GuestFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(._dismissToast(id: toast.id)) {
            $0.toastQueue = []
        }

        await clock.advance(by: .seconds(3))
    }
}

actor EventsStreamCounter {
    private let first: AsyncStream<MultipeerEvent>
    private let second: AsyncStream<MultipeerEvent>
    private var count = 0

    init(first: AsyncStream<MultipeerEvent>, second: AsyncStream<MultipeerEvent>) {
        self.first = first
        self.second = second
    }

    func nextStream() -> AsyncStream<MultipeerEvent> {
        count += 1
        return count == 1 ? first : second
    }
}

actor TerminationRecorder {
    private var terminationCount = 0

    func record() {
        terminationCount += 1
    }

    func waitForCount(_ count: Int) async {
        for _ in 0..<100 {
            if terminationCount >= count {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

actor GuestSendRecorder {
    struct Record: Equatable {
        let message: MeshMessage
        let target: Peer?
    }

    private var records: [Record] = []

    func record(message: MeshMessage, target: Peer?) {
        records.append(Record(message: message, target: target))
    }

    func waitForCount(_ count: Int) async {
        for _ in 0..<100 {
            if records.count >= count {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    var last: Record? {
        records.last
    }
}

actor GuestStartRecorder {
    private(set) var name: String?

    func record(name: String) {
        self.name = name
    }
}

actor InviteRecorder {
    private var peers: [Peer] = []

    func record(peer: Peer) {
        peers.append(peer)
    }

    func waitForCount(_ count: Int) async {
        for _ in 0..<100 {
            if peers.count >= count {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    var last: Peer? {
        peers.last
    }
}

actor GuestStopRecorder {
    private var didCallStop = false

    func record() {
        didCallStop = true
    }

    var called: Bool {
        didCallStop
    }
}

actor GuestSearchRecorder {
    private var queries: [String] = []

    func record(_ query: String) {
        queries.append(query)
    }

    var count: Int {
        queries.count
    }
}

enum GuestTestMusicKitError: Error, LocalizedError {
    case searchFailed
    case recommendationsFailed

    var errorDescription: String? {
        switch self {
        case .searchFailed:
            return "Search failed"
        case .recommendationsFailed:
            return "Recommendations failed"
        }
    }
}
