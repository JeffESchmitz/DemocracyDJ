import ComposableArchitecture
import Shared

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var mode: Mode = .modeSelection
        var displayName: String = ""

        enum Mode: Equatable {
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
    }

    enum Action {
        case displayNameChanged(String)
        case hostSelected
        case guestSelected
        case exitSession

        case host(HostFeature.Action)
        case guest(GuestFeature.Action)
    }

    @Dependency(\.multipeerClient) var multipeerClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .displayNameChanged(name):
                state.displayName = name
                return .none

            case .hostSelected:
                let trimmed = state.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    return .none
                }
                state.mode = .host(HostFeature.State(displayName: trimmed))
                return .none

            case .guestSelected:
                let trimmed = state.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    return .none
                }
                state.mode = .guest(GuestFeature.State())
                return .none

            case .exitSession:
                state.mode = .modeSelection
                return .run { _ in
                    await multipeerClient.stop()
                }

            case .host:
                return .none

            case .guest:
                return .none
            }
        }
        .ifLet(\.hostState, action: /Action.host) {
            HostFeature()
        }
        .ifLet(\.guestState, action: /Action.guest) {
            GuestFeature()
        }
    }
}
