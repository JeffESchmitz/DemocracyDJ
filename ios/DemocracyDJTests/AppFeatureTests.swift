import ComposableArchitecture
import Shared
import Testing
@testable import DemocracyDJ

@MainActor
@Suite("AppFeature")
struct AppFeatureTests {
    @Test func displayNameChanged() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.displayNameChanged("Alex")) {
            $0.displayName = "Alex"
        }
    }

    @Test func hostSelectedGuardsEmptyName() async {
        let store = TestStore(initialState: AppFeature.State(displayName: "")) {
            AppFeature()
        }

        await store.send(.hostSelected)
        #expect(store.state.mode == .modeSelection)
    }

    @Test func hostSelectedTransitions() async {
        let store = TestStore(initialState: AppFeature.State(displayName: "DJ")) {
            AppFeature()
        }

        store.exhaustivity = .off
        await store.send(.hostSelected)

        if case let .host(hostState) = store.state.mode {
            #expect(hostState.myPeer.name == "DJ")
        } else {
            #expect(false, "Expected host mode")
        }
    }

    @Test func guestSelectedTransitions() async {
        let store = TestStore(initialState: AppFeature.State(displayName: "Guest")) {
            AppFeature()
        }

        await store.send(.guestSelected) {
            $0.mode = .guest(GuestFeature.State(myPeer: nil))
        }
    }

    @Test func exitSessionStopsNetworking() async {
        let recorder = StopRecorder()
        let store = TestStore(initialState: AppFeature.State(
            mode: .guest(GuestFeature.State(myPeer: nil)),
            displayName: "Guest"
        )) {
            AppFeature()
        } withDependencies: {
            $0.multipeerClient = .mock(
                onStop: {
                    await recorder.record()
                }
            )
        }

        await store.send(.exitSession) {
            $0.mode = .modeSelection
        }

        await recorder.waitForCount(1)
        #expect(await recorder.count == 1)
    }

    @Test func hostExitTappedTriggersExitSession() async {
        let recorder = StopRecorder()
        let store = TestStore(
            initialState: AppFeature.State(
                mode: .host(HostFeature.State(displayName: "Host")),
                displayName: "Host"
            )
        ) {
            AppFeature()
        } withDependencies: {
            $0.multipeerClient = .mock(
                onStop: { await recorder.record() }
            )
        }

        await store.send(.host(.exitTapped))
        await store.receive(\.exitSession) {
            $0.mode = .modeSelection
        }

        await recorder.waitForCount(1)
        #expect(await recorder.count == 1)
    }
}

actor StopRecorder {
    private var stopCount = 0

    func record() {
        stopCount += 1
    }

    func waitForCount(_ count: Int) async {
        for _ in 0..<100 {
            if stopCount >= count {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    var count: Int {
        stopCount
    }
}
