import ComposableArchitecture
import Foundation
import Shared
import Testing
@testable import DemocracyDJ

@MainActor
@Suite("AppFeature")
struct AppFeatureTests {
    // MARK: - Onboarding Tests

    @Test func onAppearShowsOnboardingForNewUser() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.userDefaultsClient = .mock(
                hasCompletedOnboarding: { false },
                displayName: { nil }
            )
        }

        await store.send(.onAppear) {
            $0.hasCheckedOnboarding = true
        }
        await store.receive(\._loadedOnboardingStatus) {
            $0.mode = .onboarding(OnboardingFeature.State())
        }
    }

    @Test func onAppearSkipsOnboardingForReturningUser() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.userDefaultsClient = .mock(
                hasCompletedOnboarding: { true },
                displayName: { "Jeff" }
            )
        }

        await store.send(.onAppear) {
            $0.hasCheckedOnboarding = true
        }
        await store.receive(\._loadedOnboardingStatus) {
            $0.displayName = "Jeff"
            $0.mode = .modeSelection
        }
    }

    @Test func onAppearOnlyRunsOnce() async {
        let store = TestStore(initialState: AppFeature.State(hasCheckedOnboarding: true)) {
            AppFeature()
        } withDependencies: {
            $0.userDefaultsClient = .mock()
        }

        // Should do nothing since already checked
        await store.send(.onAppear)
    }

    @Test func onboardingCompletionPersistsAndTransitions() async {
        let didSetCompleted = LockedBox(false)
        let savedName = LockedBox<String?>(nil)

        let store = TestStore(
            initialState: AppFeature.State(
                mode: .onboarding(OnboardingFeature.State(displayName: "Jeff"))
            )
        ) {
            AppFeature()
        } withDependencies: {
            $0.userDefaultsClient = .mock(
                setHasCompletedOnboarding: { _ in
                    didSetCompleted.withValue { $0 = true }
                },
                setDisplayName: { name in
                    savedName.withValue { $0 = name }
                }
            )
        }

        await store.send(AppFeature.Action.onboarding(.delegate(.completed(displayName: "Jeff")))) {
            $0.displayName = "Jeff"
            $0.mode = AppFeature.State.Mode.modeSelection
        }

        #expect(didSetCompleted.current == true)
        #expect(savedName.current == "Jeff")
    }

    @Test func onboardingRestoresDisplayNameOnSkip() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.userDefaultsClient = .mock(
                hasCompletedOnboarding: { true },
                displayName: { "SavedUser" }
            )
        }

        await store.send(.onAppear) {
            $0.hasCheckedOnboarding = true
        }
        await store.receive(\._loadedOnboardingStatus) {
            $0.displayName = "SavedUser"
            $0.mode = .modeSelection
        }
    }

    // MARK: - Display Name Tests

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
        await store.receive(\.host)

        if case let .host(hostState) = store.state.mode {
            #expect(hostState.myPeer.name == "DJ")
            #expect(hostState.isHosting)
        } else {
            #expect(false, "Expected host mode")
        }
    }

    @Test func guestSelectedTransitions() async {
        let store = TestStore(initialState: AppFeature.State(displayName: "Guest")) {
            AppFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }

        await store.send(.guestSelected) {
            $0.mode = AppFeature.State.Mode.guest(GuestFeature.State(myPeer: nil))
        }
        await store.receive(\.guest) {
            $0.guestState?.myPeer = Peer(id: UUID(0).uuidString, name: "Guest")
            $0.guestState?.connectionStatus = .browsing
            $0.guestState?.availableHosts = []
            $0.guestState?.hostSnapshot = nil
            $0.guestState?.pendingVotes = []
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

        await store.send(.exitSession)
        await store.receive(\.guest)
        await store.receive(\._resetToModeSelection) {
            $0.mode = .modeSelection
        }

        await recorder.waitForCount(1)
        #expect(await recorder.count == 1)
    }

    @Test func hostSelectedStartsHosting() async {
        let store = TestStore(initialState: AppFeature.State(displayName: "Driver")) {
            AppFeature()
        } withDependencies: {
            $0.multipeerClient = .mock()
        }

        store.exhaustivity = .off
        await store.send(.hostSelected)
        await store.receive(\.host)
        #expect(store.state.hostState?.isHosting == true)
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
        await store.receive(\.exitSession)
        await store.receive(\.host)
        await store.receive(\._resetToModeSelection) {
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

final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withValue<T>(_ body: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }

    var current: Value {
        withValue { $0 }
    }
}
