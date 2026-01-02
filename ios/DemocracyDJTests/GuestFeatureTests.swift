import ComposableArchitecture
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
        let snapshot = HostSnapshot(nowPlaying: nil, queue: [], connectedPeers: [])
        let store = TestStore(initialState: GuestFeature.State(
            myPeer: Peer(id: "guest", name: "Guest"),
            hostSnapshot: nil,
            pendingVotes: ["song-1"]
        )) {
            GuestFeature()
        }

        await store.send(GuestFeature.Action._snapshotReceived(snapshot)) {
            $0.hostSnapshot = snapshot
            $0.pendingVotes = []
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

        let store = TestStore(initialState: GuestFeature.State()) {
            GuestFeature()
        } withDependencies: {
            $0.multipeerClient = .mock(
                onInvite: { peer in
                    await recorder.record(peer: peer)
                }
            )
        }

        await store.send(.connectToHost(host)) {
            $0.connectionStatus = .connecting(host: host)
        }

        await recorder.waitForCount(1)
        let last = await recorder.last
        #expect(last == host)
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
            availableHosts: [Peer(id: "host", name: "Host")]
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
