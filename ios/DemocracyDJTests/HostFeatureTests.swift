import ComposableArchitecture
import Foundation
import Shared
import Testing
import struct MusicKit.MusicAuthorization
@testable import DemocracyDJ

@MainActor
@Suite("HostFeature")
struct HostFeatureTests {
    @Test func requestMusicAuthorizationStoresStatus() async {
        let host = Peer(id: "host", name: "Host")
        let store = TestStore(initialState: HostFeature.State(myPeer: host)) {
            HostFeature()
        } withDependencies: {
            $0.musicKitClient = .mock(
                requestAuthorization: { .authorized }
            )
        }

        await store.send(.requestMusicAuthorization)

        await store.receive(._authorizationStatusUpdated(.authorized)) {
            $0.musicAuthorizationStatus = .authorized
        }
    }

    @Test func playTappedStartsPlayback() async {
        let host = Peer(id: "host", name: "Host")
        let song = Song(id: "song-1", title: "Test", artist: "Artist", albumArtURL: nil, duration: 180)
        let recorder = MusicPlaybackRecorder()

        let store = TestStore(initialState: HostFeature.State(
            myPeer: host,
            nowPlaying: song,
            musicAuthorizationStatus: .authorized,
            subscriptionStatus: SubscriptionStatus(canPlayCatalogContent: true, canBecomeSubscriber: false)
        )) {
            HostFeature()
        } withDependencies: {
            $0.musicKitClient = .mock(
                play: { played in
                    await recorder.recordPlay(played)
                }
            )
        }

        await store.send(.playTapped)

        await recorder.waitForPlay()
        #expect(await recorder.playedSong == song)
    }

    @Test func playTappedRequiresAuthorization() async {
        let host = Peer(id: "host", name: "Host")
        let song = Song(id: "song-1", title: "Test", artist: "Artist", albumArtURL: nil, duration: 180)

        let store = TestStore(initialState: HostFeature.State(
            myPeer: host,
            nowPlaying: song,
            musicAuthorizationStatus: .notDetermined
        )) {
            HostFeature()
        }

        await store.send(.playTapped) {
            $0.alert = AlertState {
                TextState("Music Access Required")
            } actions: {
                ButtonState(action: .openSettings) { TextState("Open Settings") }
                ButtonState(role: .cancel, action: .dismiss) { TextState("Cancel") }
            } message: {
                TextState("Please authorize Apple Music to play songs.")
            }
        }
    }

    @Test func playTappedRequiresSubscription() async {
        let host = Peer(id: "host", name: "Host")
        let song = Song(id: "song-1", title: "Test", artist: "Artist", albumArtURL: nil, duration: 180)

        let store = TestStore(initialState: HostFeature.State(
            myPeer: host,
            nowPlaying: song,
            musicAuthorizationStatus: .authorized,
            subscriptionStatus: SubscriptionStatus(canPlayCatalogContent: false, canBecomeSubscriber: true)
        )) {
            HostFeature()
        }

        await store.send(.playTapped) {
            $0.alert = AlertState {
                TextState("Apple Music Subscription Required")
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) { TextState("OK") }
            } message: {
                TextState("An active Apple Music subscription is required to play songs.")
            }
        }
    }

    @Test func pauseTappedStopsPlayback() async {
        let host = Peer(id: "host", name: "Host")
        let song = Song(id: "song-1", title: "Test", artist: "Artist", albumArtURL: nil, duration: 180)
        let recorder = MusicPlaybackRecorder()

        let store = TestStore(initialState: HostFeature.State(
            myPeer: host,
            nowPlaying: song,
            isPlaying: true,
            musicAuthorizationStatus: .authorized
        )) {
            HostFeature()
        } withDependencies: {
            $0.musicKitClient = .mock(
                pause: {
                    await recorder.recordPause()
                }
            )
        }

        await store.send(.pauseTapped)

        await recorder.waitForPause()
        #expect(await recorder.pauseCount == 1)
    }

    @Test func playbackErrorShowsAlert() async {
        let host = Peer(id: "host", name: "Host")
        let song = Song(id: "song-1", title: "Test", artist: "Artist", albumArtURL: nil, duration: 180)

        let store = TestStore(initialState: HostFeature.State(
            myPeer: host,
            nowPlaying: song,
            musicAuthorizationStatus: .authorized,
            subscriptionStatus: SubscriptionStatus(canPlayCatalogContent: true, canBecomeSubscriber: false)
        )) {
            HostFeature()
        } withDependencies: {
            $0.musicKitClient = .mock(
                play: { _ in throw TestMusicKitError.playbackFailed }
            )
        }

        await store.send(.playTapped)
        await store.receive(._playbackError("Playback failed")) {
            $0.alert = AlertState {
                TextState("Playback Error")
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) { TextState("OK") }
            } message: {
                TextState("Playback failed")
            }
        }
    }

    @Test func votingIsIdempotent() async {
        let host = Peer(id: "host", name: "Host")
        let guest = Peer(id: "guest", name: "Guest")
        let song = Song(id: "song-1", title: "One", artist: "Artist", albumArtURL: nil, duration: 120)
        let item = QueueItem(id: song.id, song: song, addedBy: host, voters: [])

        let store = TestStore(initialState: HostFeature.State(myPeer: host, queue: [item])) {
            HostFeature()
        }

        await store.send(._processIntent(.vote(songID: song.id), from: guest)) {
            $0.queue[0].voters = [guest.id]
        }
        await store.receive(._broadcastSnapshot)

        await store.send(._processIntent(.vote(songID: song.id), from: guest))
    }

    @Test func voteSortingIsStableOnTie() async {
        let host = Peer(id: "host", name: "Host")
        let voter = Peer(id: "guest", name: "Guest")
        let firstSong = Song(id: "song-1", title: "One", artist: "Artist", albumArtURL: nil, duration: 120)
        let secondSong = Song(id: "song-2", title: "Two", artist: "Artist", albumArtURL: nil, duration: 140)
        let first = QueueItem(id: firstSong.id, song: firstSong, addedBy: host, voters: ["voter-a"])
        let second = QueueItem(id: secondSong.id, song: secondSong, addedBy: host, voters: [])

        let store = TestStore(initialState: HostFeature.State(myPeer: host, queue: [first, second])) {
            HostFeature()
        }

        await store.send(._processIntent(.vote(songID: secondSong.id), from: voter)) {
            $0.queue[1].voters = [voter.id]
        }
        await store.receive(._broadcastSnapshot)

        #expect(store.state.queue.map(\.id) == [firstSong.id, secondSong.id])
    }

    @Test func skipPromotesQueueAndClearsWhenEmpty() async {
        let host = Peer(id: "host", name: "Host")
        let firstSong = Song(id: "song-1", title: "One", artist: "Artist", albumArtURL: nil, duration: 120)
        let secondSong = Song(id: "song-2", title: "Two", artist: "Artist", albumArtURL: nil, duration: 140)
        let first = QueueItem(id: firstSong.id, song: firstSong, addedBy: host, voters: [])
        let second = QueueItem(id: secondSong.id, song: secondSong, addedBy: host, voters: [])

        let store = TestStore(initialState: HostFeature.State(myPeer: host, queue: [first, second])) {
            HostFeature()
        }

        await store.send(.skipTapped) {
            $0.nowPlaying = firstSong
            $0.queue = [second]
        }
        await store.receive(._broadcastSnapshot)

        await store.send(.skipTapped) {
            $0.nowPlaying = secondSong
            $0.queue = []
        }
        await store.receive(._broadcastSnapshot)

        await store.send(.skipTapped) {
            $0.nowPlaying = nil
        }
        await store.receive(._broadcastSnapshot)
    }

    @Test func removeSongFromQueueRemovesAndBroadcasts() async {
        let host = Peer(id: "host", name: "Host")
        let song = Song(id: "song-1", title: "Remove Me", artist: "Artist", albumArtURL: nil, duration: 180)
        let item = QueueItem(id: song.id, song: song, addedBy: host, voters: [])

        let store = TestStore(initialState: HostFeature.State(myPeer: host, queue: [item])) {
            HostFeature()
        }

        await store.send(.removeSongTapped(id: song.id)) {
            $0.alert = AlertState {
                TextState("Remove Song?")
            } actions: {
                ButtonState(role: .destructive, action: .confirmRemoveSong(song.id)) {
                    TextState("Remove")
                }
                ButtonState(role: .cancel, action: .dismiss) { TextState("Cancel") }
            } message: {
                TextState("This will remove the song from the queue for everyone.")
            }
        }

        await store.send(.alert(.presented(.confirmRemoveSong(song.id)))) {
            $0.alert = nil
        }

        await store.receive(.removeSongFromQueue(id: song.id)) {
            $0.queue = []
        }
        await store.receive(._broadcastSnapshot)
    }

    @Test func removeNonExistentSongIsNoOp() async {
        let host = Peer(id: "host", name: "Host")
        let song = Song(id: "song-1", title: "Keep Me", artist: "Artist", albumArtURL: nil, duration: 180)
        let item = QueueItem(id: song.id, song: song, addedBy: host, voters: [])

        let store = TestStore(initialState: HostFeature.State(myPeer: host, queue: [item])) {
            HostFeature()
        }

        await store.send(.removeSongFromQueue(id: "missing"))
    }

    @Test func removeNowPlayingSongIsNoOp() async {
        let host = Peer(id: "host", name: "Host")
        let song = Song(id: "song-1", title: "Now Playing", artist: "Artist", albumArtURL: nil, duration: 180)
        let item = QueueItem(id: song.id, song: song, addedBy: host, voters: [])

        let store = TestStore(initialState: HostFeature.State(
            myPeer: host,
            nowPlaying: song,
            queue: [item]
        )) {
            HostFeature()
        }

        await store.send(.removeSongFromQueue(id: song.id))
    }

    @Test func removeLastSongLeavesEmptyQueue() async {
        let host = Peer(id: "host", name: "Host")
        let song = Song(id: "song-1", title: "Last Song", artist: "Artist", albumArtURL: nil, duration: 180)
        let item = QueueItem(id: song.id, song: song, addedBy: host, voters: [])

        let store = TestStore(initialState: HostFeature.State(myPeer: host, queue: [item])) {
            HostFeature()
        }

        await store.send(.removeSongFromQueue(id: song.id)) {
            $0.queue = []
        }
        await store.receive(._broadcastSnapshot)
    }

    @Test func broadcastsSnapshotOnPeerConnectedEvenWithoutChange() async {
        let host = Peer(id: "host", name: "Host")
        let peer = Peer(id: "peer-1", name: "Peer")
        let recorder = SendRecorder()

        let store = TestStore(initialState: HostFeature.State(
            myPeer: host,
            connectedPeers: [peer],
            isHosting: true
        )) {
            HostFeature()
        } withDependencies: {
            $0.multipeerClient = .mock(
                onSend: { message, target in
                    await recorder.record(message: message, target: target)
                }
            )
        }

        await store.send(.multipeerEvent(.peerConnected(peer)))
        await store.receive(._broadcastSnapshot)

        await recorder.waitForCount(1)
        let record = await recorder.last
        #expect(record?.message == .stateUpdate(
            HostSnapshot(nowPlaying: nil, queue: [], connectedPeers: [peer])
        ))
        #expect(record?.target == nil)
    }

    @Test func startHostingSubscribesToEvents() async {
        let host = Peer(id: "host", name: "Host")
        let guest = Peer(id: "guest", name: "Guest")
        let recorder = StartRecorder()
        var continuation: AsyncStream<MultipeerEvent>.Continuation?
        let stream = AsyncStream<MultipeerEvent> { streamContinuation in
            continuation = streamContinuation
        }

        let store = TestStore(initialState: HostFeature.State(myPeer: host)) {
            HostFeature()
        } withDependencies: {
            $0.multipeerClient = .mock(
                events: { stream },
                onStartHosting: { displayName in
                    await recorder.record(name: displayName)
                }
            )
            $0.musicKitClient = .mock(
                playbackStatus: { AsyncStream { _ in } },
                checkSubscription: {
                    SubscriptionStatus(canPlayCatalogContent: true, canBecomeSubscriber: false)
                }
            )
            $0.nowPlayingClient = .mock(
                remoteCommands: { AsyncStream { _ in } }
            )
        }

        await store.send(.startHosting) {
            $0.isHosting = true
        }
        await store.receive(._subscriptionStatusUpdated(SubscriptionStatus(
            canPlayCatalogContent: true,
            canBecomeSubscriber: false
        ))) {
            $0.subscriptionStatus = SubscriptionStatus(
                canPlayCatalogContent: true,
                canBecomeSubscriber: false
            )
        }

        continuation?.yield(.peerConnected(guest))
        await store.receive(.multipeerEvent(.peerConnected(guest))) {
            $0.connectedPeers = [guest]
        }
        await store.receive(._broadcastSnapshot)

        let startedName = await recorder.name
        #expect(startedName == host.name)

        await store.send(.stopHosting) {
            $0.isHosting = false
        }
        await store.finish()
    }

    @Test func exitTappedIsNoOp() async {
        let host = Peer(id: "host", name: "Host")
        let store = TestStore(initialState: HostFeature.State(myPeer: host)) {
            HostFeature()
        }

        await store.send(.exitTapped)
    }

    @Test func stopHostingCancelsEventStream() async {
        let host = Peer(id: "host", name: "Host")
        let guest = Peer(id: "guest", name: "Guest")
        var continuation: AsyncStream<MultipeerEvent>.Continuation?
        let stream = AsyncStream<MultipeerEvent> { streamContinuation in
            continuation = streamContinuation
        }

        let store = TestStore(initialState: HostFeature.State(myPeer: host)) {
            HostFeature()
        } withDependencies: {
            $0.multipeerClient = .mock(events: { stream })
            $0.musicKitClient = .mock(
                playbackStatus: { AsyncStream { _ in } }
            )
            $0.nowPlayingClient = .mock(
                remoteCommands: { AsyncStream { _ in } }
            )
        }

        await store.send(.startHosting) {
            $0.isHosting = true
        }
        await store.receive(._subscriptionStatusUpdated(.unknown))

        await store.send(.stopHosting) {
            $0.isHosting = false
        }

        continuation?.yield(.peerConnected(guest))
        await store.finish()
    }

    @Test func startHostingTwiceDoesNotDuplicateEvents() async {
        let host = Peer(id: "host", name: "Host")
        let terminationRecorder = HostTerminationRecorder()
        let firstStream = AsyncStream<MultipeerEvent> { continuation in
            continuation.onTermination = { _ in
                Task {
                    await terminationRecorder.record()
                }
            }
        }
        let secondStream = AsyncStream<MultipeerEvent> { _ in }
        let eventsCounter = HostEventsStreamCounter(first: firstStream, second: secondStream)

        let store = TestStore(initialState: HostFeature.State(myPeer: host)) {
            HostFeature()
        } withDependencies: {
            $0.multipeerClient = .mock(events: { await eventsCounter.nextStream() })
            $0.musicKitClient = .mock(
                playbackStatus: { AsyncStream { _ in } }
            )
            $0.nowPlayingClient = .mock(
                remoteCommands: { AsyncStream { _ in } }
            )
        }

        await store.send(.startHosting) {
            $0.isHosting = true
        }
        await store.receive(._subscriptionStatusUpdated(.unknown))
        await store.send(.startHosting)
        await store.receive(._subscriptionStatusUpdated(.unknown))

        await terminationRecorder.waitForCount(1)

        await store.send(.stopHosting) {
            $0.isHosting = false
        }
        await store.finish()
    }

    @Test func playbackStatusUpdatesState() async {
        let host = Peer(id: "host", name: "Host")
        let store = TestStore(initialState: HostFeature.State(myPeer: host)) {
            HostFeature()
        }

        let status = PlaybackStatus(isPlaying: true, currentTime: 30, duration: 180)
        await store.send(._playbackStatusUpdated(status)) {
            $0.playbackStatus = status
            $0.isPlaying = true
        }
    }

    @Test func canPlayRequiresAuthorizationAndSubscription() async {
        let host = Peer(id: "host", name: "Host")
        var state = HostFeature.State(myPeer: host)

        #expect(state.canPlay == false)

        state.musicAuthorizationStatus = .authorized
        #expect(state.canPlay == false)

        state.subscriptionStatus = SubscriptionStatus(canPlayCatalogContent: true, canBecomeSubscriber: false)
        #expect(state.canPlay == true)
    }

    @Test func songFinishedAdvancesQueue() async {
        let host = Peer(id: "host", name: "Host")
        let firstSong = Song(id: "song-1", title: "One", artist: "Artist", albumArtURL: nil, duration: 180)
        let secondSong = Song(id: "song-2", title: "Two", artist: "Artist", albumArtURL: nil, duration: 200)
        let queued = QueueItem(id: secondSong.id, song: secondSong, addedBy: host, voters: [])

        let store = TestStore(initialState: HostFeature.State(
            myPeer: host,
            nowPlaying: firstSong,
            queue: [queued],
            isPlaying: true,
            playbackStatus: PlaybackStatus(isPlaying: true, currentTime: 0, duration: 180)
        )) {
            HostFeature()
        }

        let finished = PlaybackStatus(isPlaying: false, currentTime: 179, duration: 180)
        await store.send(._playbackStatusUpdated(finished)) {
            $0.playbackStatus = finished
            $0.isPlaying = false
        }

        await store.receive(.skipTapped) {
            $0.nowPlaying = secondSong
            $0.queue = []
        }
        await store.receive(._broadcastSnapshot)
    }

    @Test func searchResultsReceivedUpdatesState() async {
        let host = Peer(id: "host", name: "Host")
        let song = Song(id: "song-1", title: "Test", artist: "Artist", albumArtURL: nil, duration: 180)

        let store = TestStore(initialState: HostFeature.State(
            myPeer: host,
            isSearching: true
        )) {
            HostFeature()
        }

        await store.send(.searchResultsReceived([song])) {
            $0.searchResults = [song]
            $0.isSearching = false
        }
    }

    @Test func songSelectedAddsToQueueAndBroadcasts() async {
        let host = Peer(id: "host", name: "Host")
        let song = Song(id: "song-1", title: "Test", artist: "Artist", albumArtURL: nil, duration: 180)

        let store = TestStore(initialState: HostFeature.State(
            myPeer: host,
            isSearchSheetPresented: true,
            searchQuery: "test",
            searchResults: [song],
            isSearching: true
        )) {
            HostFeature()
        }

        await store.send(.songSelected(song)) {
            $0.isSearchSheetPresented = false
            $0.searchQuery = ""
            $0.searchResults = []
            $0.isSearching = false
            $0.queue = [
                QueueItem(id: song.id, song: song, addedBy: host, voters: [])
            ]
        }
        await store.receive(._broadcastSnapshot)
    }

    @Test func duplicateSongSelectedClosesSheetWithoutBroadcast() async {
        let host = Peer(id: "host", name: "Host")
        let song = Song(id: "song-1", title: "Test", artist: "Artist", albumArtURL: nil, duration: 180)
        let item = QueueItem(id: song.id, song: song, addedBy: host, voters: [])

        let store = TestStore(initialState: HostFeature.State(
            myPeer: host,
            nowPlaying: song,
            queue: [item],
            isSearchSheetPresented: true,
            searchQuery: "test",
            searchResults: [song],
            isSearching: true
        )) {
            HostFeature()
        }

        await store.send(.songSelected(song)) {
            $0.isSearchSheetPresented = false
            $0.searchQuery = ""
            $0.searchResults = []
            $0.isSearching = false
        }
    }

    @Test func searchQueryDebounced() async {
        let host = Peer(id: "host", name: "Host")
        let clock = TestClock()
        let song = Song(id: "song-1", title: "Result", artist: "Artist", albumArtURL: nil, duration: 180)

        let store = TestStore(initialState: HostFeature.State(myPeer: host)) {
            HostFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.musicKitClient = .mock(search: { _ in [song] })
        }

        await store.send(.searchQueryChanged("test")) {
            $0.searchQuery = "test"
            $0.isSearching = true
        }

        await clock.advance(by: .milliseconds(300))

        await store.receive(.searchResultsReceived([song])) {
            $0.searchResults = [song]
            $0.isSearching = false
        }
    }

    @Test func searchErrorShowsAlert() async {
        let host = Peer(id: "host", name: "Host")
        let clock = TestClock()

        let store = TestStore(initialState: HostFeature.State(myPeer: host)) {
            HostFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.musicKitClient = .mock(search: { _ in
                throw TestMusicKitError.searchFailed
            })
        }

        await store.send(.searchQueryChanged("test")) {
            $0.searchQuery = "test"
            $0.isSearching = true
        }

        await clock.advance(by: .milliseconds(300))

        await store.receive(._searchError("Search failed")) {
            $0.isSearching = false
            $0.alert = AlertState {
                TextState("Search Error")
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) { TextState("OK") }
            } message: {
                TextState("Search failed")
            }
        }
    }

    @Test func dismissSearchClearsStateAndCancelsInFlightSearch() async {
        let host = Peer(id: "host", name: "Host")
        let clock = TestClock()
        let recorder = HostSearchRecorder()
        let song = Song(id: "song-1", title: "Result", artist: "Artist", albumArtURL: nil, duration: 180)

        let store = TestStore(initialState: HostFeature.State(
            myPeer: host,
            isSearchSheetPresented: true
        )) {
            HostFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.musicKitClient = .mock(search: { query in
                await recorder.record(query)
                return [song]
            })
        }

        await store.send(.searchQueryChanged("test")) {
            $0.searchQuery = "test"
            $0.isSearching = true
        }

        await store.send(.dismissSearch) {
            $0.isSearchSheetPresented = false
            $0.searchQuery = ""
            $0.searchResults = []
            $0.isSearching = false
        }

        await clock.advance(by: .milliseconds(300))
        #expect(await recorder.count == 0)

        await store.finish()
    }

    @Test func emptySearchQueryClearsResultsAndStopsSearching() async {
        let host = Peer(id: "host", name: "Host")
        let clock = TestClock()
        let recorder = HostSearchRecorder()
        let song = Song(id: "song-1", title: "Result", artist: "Artist", albumArtURL: nil, duration: 180)

        let store = TestStore(initialState: HostFeature.State(
            myPeer: host,
            searchQuery: "old",
            searchResults: [song],
            isSearching: true
        )) {
            HostFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.musicKitClient = .mock(search: { query in
                await recorder.record(query)
                return [song]
            })
        }

        await store.send(.searchQueryChanged("")) {
            $0.searchQuery = ""
            $0.searchResults = []
            $0.isSearching = false
        }

        await clock.advance(by: .milliseconds(300))
        #expect(await recorder.count == 0)

        await store.finish()
    }

    @Test func duplicateSongInQueueDoesNotBroadcast() async {
        let host = Peer(id: "host", name: "Host")
        let song = Song(id: "song-1", title: "Test", artist: "Artist", albumArtURL: nil, duration: 180)
        let item = QueueItem(id: song.id, song: song, addedBy: host, voters: [])

        let store = TestStore(initialState: HostFeature.State(
            myPeer: host,
            queue: [item],
            isSearchSheetPresented: true,
            searchQuery: "test",
            searchResults: [song],
            isSearching: true
        )) {
            HostFeature()
        }

        await store.send(.songSelected(song)) {
            $0.isSearchSheetPresented = false
            $0.searchQuery = ""
            $0.searchResults = []
            $0.isSearching = false
        }
    }
}

actor SendRecorder {
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

actor StartRecorder {
    private(set) var name: String?

    func record(name: String) {
        self.name = name
    }
}

actor StartCountRecorder {
    private var count = 0

    func record() {
        count += 1
    }

    func waitForCount(_ target: Int) async {
        for _ in 0..<100 {
            if count >= target {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

actor MusicPlaybackRecorder {
    private var play: Song?
    private var pauseCalls = 0

    func recordPlay(_ song: Song) {
        play = song
    }

    func recordPause() {
        pauseCalls += 1
    }

    func waitForPlay() async {
        for _ in 0..<100 {
            if play != nil {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func waitForPause() async {
        for _ in 0..<100 {
            if pauseCalls > 0 {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    var playedSong: Song? {
        play
    }

    var pauseCount: Int {
        pauseCalls
    }
}

actor HostEventsStreamCounter {
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

actor HostTerminationRecorder {
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

actor HostSearchRecorder {
    private var queries: [String] = []

    func record(_ query: String) {
        queries.append(query)
    }

    var count: Int {
        queries.count
    }
}

enum TestMusicKitError: Error, LocalizedError {
    case playbackFailed
    case searchFailed

    var errorDescription: String? {
        switch self {
        case .playbackFailed:
            return "Playback failed"
        case .searchFailed:
            return "Search failed"
        }
    }
}
