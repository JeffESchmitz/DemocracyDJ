import ComposableArchitecture
import Shared

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var mode: Mode = .modeSelection
        var displayName: String = ""
        var hasCheckedOnboarding: Bool = false

        enum Mode: Equatable {
            case onboarding(OnboardingFeature.State)
            case modeSelection
            case host(HostFeature.State)
            case guest(GuestFeature.State)
        }

        var hostState: HostFeature.State? {
            get {
                guard case let .host(state) = mode else { return nil }
                return state
            }
            set {
                guard let newValue else {
                    mode = .modeSelection
                    return
                }
                mode = .host(newValue)
            }
        }

        var guestState: GuestFeature.State? {
            get {
                guard case let .guest(state) = mode else { return nil }
                return state
            }
            set {
                guard let newValue else {
                    mode = .modeSelection
                    return
                }
                mode = .guest(newValue)
            }
        }

        var onboardingState: OnboardingFeature.State? {
            get {
                guard case let .onboarding(state) = mode else { return nil }
                return state
            }
            set {
                guard let newValue else {
                    mode = .modeSelection
                    return
                }
                mode = .onboarding(newValue)
            }
        }
    }

    enum Action {
        case onAppear
        case displayNameChanged(String)
        case hostSelected
        case guestSelected
        case exitSession
        case _resetToModeSelection
        case _loadedOnboardingStatus(hasCompleted: Bool, displayName: String?)

        case onboarding(OnboardingFeature.Action)
        case host(HostFeature.Action)
        case guest(GuestFeature.Action)
    }

    @Dependency(\.multipeerClient) var multipeerClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.hasCheckedOnboarding else { return .none }
                state.hasCheckedOnboarding = true
                let hasCompleted = userDefaultsClient.hasCompletedOnboarding()
                let savedName = userDefaultsClient.displayName()
                return .send(._loadedOnboardingStatus(hasCompleted: hasCompleted, displayName: savedName))

            case let ._loadedOnboardingStatus(hasCompleted, displayName):
                if hasCompleted {
                    state.displayName = displayName ?? ""
                    state.mode = .modeSelection
                } else {
                    state.mode = .onboarding(OnboardingFeature.State())
                }
                return .none

            case .onboarding(.delegate(.completed(let displayName))):
                userDefaultsClient.setHasCompletedOnboarding(true)
                userDefaultsClient.setDisplayName(displayName)
                state.displayName = displayName
                state.mode = .modeSelection
                return .none

            case .onboarding:
                return .none

            case let .displayNameChanged(name):
                state.displayName = name
                return .none

            case .hostSelected:
                let trimmed = state.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    return .none
                }
                state.mode = .host(HostFeature.State(displayName: trimmed))
                return .send(.host(.startHosting))

            case .guestSelected:
                let trimmed = state.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    return .none
                }
                state.mode = .guest(GuestFeature.State(myPeer: nil))
                return .send(.guest(.startBrowsing(displayName: trimmed)))

            case .exitSession:
                switch state.mode {
                case .host:
                    return .concatenate(
                        .send(.host(.stopHosting)),
                        .send(._resetToModeSelection)
                    )
                case .guest:
                    return .concatenate(
                        .send(.guest(.stopBrowsing)),
                        .send(._resetToModeSelection)
                    )
                case .modeSelection, .onboarding:
                    return .none
                }

            case ._resetToModeSelection:
                state.mode = .modeSelection
                return .none

            case .host(.exitTapped):
                return .send(.exitSession)

            case .guest(.exitTapped):
                return .send(.exitSession)

            case .host:
                return .none

            case .guest:
                return .none
            }
        }
        .ifLet(\.onboardingState, action: /Action.onboarding) {
            OnboardingFeature()
        }
        .ifLet(\.hostState, action: /Action.host) {
            HostFeature()
        }
        .ifLet(\.guestState, action: /Action.guest) {
            GuestFeature()
        }
    }
}
