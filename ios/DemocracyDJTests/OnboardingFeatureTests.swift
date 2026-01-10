import ComposableArchitecture
import Testing
@testable import DemocracyDJ

@MainActor
@Suite("OnboardingFeature")
struct OnboardingFeatureTests {
    @Test func nextTappedAdvancesFromWelcome() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.nextTapped) {
            $0.currentPage = .howItWorks
        }
    }

    @Test func nextTappedAdvancesFromHowItWorks() async {
        let store = TestStore(initialState: OnboardingFeature.State(currentPage: .howItWorks)) {
            OnboardingFeature()
        }

        await store.send(.nextTapped) {
            $0.currentPage = .displayName
        }
    }

    @Test func backTappedReturnsFromHowItWorks() async {
        let store = TestStore(initialState: OnboardingFeature.State(currentPage: .howItWorks)) {
            OnboardingFeature()
        }

        await store.send(.backTapped) {
            $0.currentPage = .welcome
        }
    }

    @Test func backTappedDoesNothingOnWelcome() async {
        let store = TestStore(initialState: OnboardingFeature.State(currentPage: .welcome)) {
            OnboardingFeature()
        }

        await store.send(.backTapped)
    }

    @Test func displayNameChanged() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.displayNameChanged("Jeff")) {
            $0.displayName = "Jeff"
        }
    }

    @Test func displayNameTruncatesAt20Characters() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        let longName = "ThisNameIsWayTooLongForTheLimit"
        await store.send(.displayNameChanged(longName)) {
            $0.displayName = "ThisNameIsWayTooLong" // 20 chars
        }
    }

    @Test func cannotProceedFromDisplayNameWithEmptyName() async {
        let store = TestStore(initialState: OnboardingFeature.State(currentPage: .displayName)) {
            OnboardingFeature()
        }

        // Next should do nothing when name is empty
        await store.send(.nextTapped)
        #expect(store.state.currentPage == .displayName)
    }

    @Test func cannotProceedFromDisplayNameWithWhitespaceOnly() async {
        let store = TestStore(initialState: OnboardingFeature.State(
            currentPage: .displayName,
            displayName: "   "
        )) {
            OnboardingFeature()
        }

        // Name is only whitespace - should not proceed
        await store.send(.nextTapped)
        #expect(store.state.currentPage == .displayName)
    }

    @Test func canProceedFromDisplayNameWithValidName() async {
        let store = TestStore(initialState: OnboardingFeature.State(
            currentPage: .displayName,
            displayName: "Jeff"
        )) {
            OnboardingFeature()
        }

        await store.send(.nextTapped) {
            $0.currentPage = .getStarted
        }
    }

    @Test func getStartedTappedEmitsDelegateWithValidName() async {
        let store = TestStore(initialState: OnboardingFeature.State(
            currentPage: .getStarted,
            displayName: "Jeff"
        )) {
            OnboardingFeature()
        }

        await store.send(.getStartedTapped)
        await store.receive(\.delegate)
    }

    @Test func getStartedTappedTrimsWhitespace() async {
        let store = TestStore(initialState: OnboardingFeature.State(
            currentPage: .getStarted,
            displayName: "  Jeff  "
        )) {
            OnboardingFeature()
        }

        await store.send(.getStartedTapped)
        await store.receive(.delegate(.completed(displayName: "Jeff")))
    }

    @Test func getStartedTappedIgnoredWithEmptyName() async {
        let store = TestStore(initialState: OnboardingFeature.State(
            currentPage: .getStarted,
            displayName: ""
        )) {
            OnboardingFeature()
        }

        // Should do nothing with empty name
        await store.send(.getStartedTapped)
    }

    @Test func pageChangedAllowsBackwardNavigation() async {
        let store = TestStore(initialState: OnboardingFeature.State(currentPage: .howItWorks)) {
            OnboardingFeature()
        }

        await store.send(.pageChanged(.welcome)) {
            $0.currentPage = .welcome
        }
    }

    @Test func pageChangedAllowsForwardNavigationWithValidState() async {
        let store = TestStore(initialState: OnboardingFeature.State(
            currentPage: .displayName,
            displayName: "Jeff"
        )) {
            OnboardingFeature()
        }

        await store.send(.pageChanged(.getStarted)) {
            $0.currentPage = .getStarted
        }
    }

    @Test func pageChangedBlocksForwardNavigationWithInvalidState() async {
        let store = TestStore(initialState: OnboardingFeature.State(
            currentPage: .displayName,
            displayName: ""
        )) {
            OnboardingFeature()
        }

        // Can't swipe forward to getStarted without a valid name
        await store.send(.pageChanged(.getStarted))
        #expect(store.state.currentPage == .displayName)
    }

    @Test func isNameValidWithValidName() {
        let state = OnboardingFeature.State(displayName: "Jeff")
        #expect(state.isNameValid == true)
    }

    @Test func isNameValidWithEmptyName() {
        let state = OnboardingFeature.State(displayName: "")
        #expect(state.isNameValid == false)
    }

    @Test func isNameValidWithWhitespaceOnly() {
        let state = OnboardingFeature.State(displayName: "   ")
        #expect(state.isNameValid == false)
    }

    @Test func isNameValidWithMaxLengthName() {
        let state = OnboardingFeature.State(displayName: "12345678901234567890") // 20 chars
        #expect(state.isNameValid == true)
    }

    @Test func trimmedDisplayNameTrimsWhitespace() {
        let state = OnboardingFeature.State(displayName: "  Jeff  ")
        #expect(state.trimmedDisplayName == "Jeff")
    }
}
