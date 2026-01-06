import ComposableArchitecture

@Reducer
struct OnboardingFeature {
    @ObservableState
    struct State: Equatable {
        var currentPage: Page = .welcome
        var displayName: String = ""

        enum Page: Int, CaseIterable {
            case welcome = 0
            case howItWorks = 1
            case displayName = 2
            case getStarted = 3
        }

        var isNameValid: Bool {
            let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && trimmed.count <= 20
        }

        var trimmedDisplayName: String {
            displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var canProceedFromCurrentPage: Bool {
            switch currentPage {
            case .welcome, .howItWorks, .getStarted:
                return true
            case .displayName:
                return isNameValid
            }
        }
    }

    enum Action: Equatable {
        case nextTapped
        case backTapped
        case pageChanged(State.Page)
        case displayNameChanged(String)
        case getStartedTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case completed(displayName: String)
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .nextTapped:
                guard state.canProceedFromCurrentPage else { return .none }
                let allPages = State.Page.allCases
                guard let currentIndex = allPages.firstIndex(of: state.currentPage),
                      currentIndex + 1 < allPages.count else {
                    return .none
                }
                state.currentPage = allPages[currentIndex + 1]
                return .none

            case .backTapped:
                let allPages = State.Page.allCases
                guard let currentIndex = allPages.firstIndex(of: state.currentPage),
                      currentIndex > 0 else {
                    return .none
                }
                state.currentPage = allPages[currentIndex - 1]
                return .none

            case let .pageChanged(page):
                // Allow navigation backward freely
                if page.rawValue < state.currentPage.rawValue {
                    state.currentPage = page
                    return .none
                }
                // Allow navigation forward only if current page allows
                if state.canProceedFromCurrentPage {
                    state.currentPage = page
                }
                return .none

            case let .displayNameChanged(name):
                // Limit to 20 characters
                state.displayName = String(name.prefix(20))
                return .none

            case .getStartedTapped:
                guard state.isNameValid else { return .none }
                return .send(.delegate(.completed(displayName: state.trimmedDisplayName)))

            case .delegate:
                return .none
            }
        }
    }
}
