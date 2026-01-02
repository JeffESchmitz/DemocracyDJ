import ComposableArchitecture
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
        }

        await store.send(.startHosting) {
            $0.isHosting = true
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
        }

        await store.send(.startHosting) {
            $0.isHosting = true
        }

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
        }

        await store.send(.startHosting) {
            $0.isHosting = true
        }
        await store.send(.startHosting)

        await terminationRecorder.waitForCount(1)

        await store.send(.stopHosting) {
            $0.isHosting = false
        }
        await store.finish()
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
