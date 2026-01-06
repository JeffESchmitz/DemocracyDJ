import Dependencies
import Foundation

// MARK: - UserDefaultsClient

/// TCA dependency for UserDefaults persistence.
/// Used for onboarding completion state and display name.
struct UserDefaultsClient: Sendable {
    /// Check if onboarding has been completed.
    var hasCompletedOnboarding: @Sendable () -> Bool

    /// Set onboarding completion state.
    var setHasCompletedOnboarding: @Sendable (Bool) -> Void

    /// Get saved display name (nil if not set).
    var displayName: @Sendable () -> String?

    /// Save display name.
    var setDisplayName: @Sendable (String) -> Void
}

// MARK: - Keys

private enum Keys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let displayName = "displayName"
}

// MARK: - DependencyKey

extension UserDefaultsClient: DependencyKey {
    static let liveValue: UserDefaultsClient = .live
    static let testValue: UserDefaultsClient = .mock()
    static let previewValue: UserDefaultsClient = .mock(hasCompletedOnboarding: { false })
}

extension DependencyValues {
    var userDefaultsClient: UserDefaultsClient {
        get { self[UserDefaultsClient.self] }
        set { self[UserDefaultsClient.self] = newValue }
    }
}

// MARK: - Live Implementation

extension UserDefaultsClient {
    static let live = UserDefaultsClient(
        hasCompletedOnboarding: {
            UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding)
        },
        setHasCompletedOnboarding: { value in
            UserDefaults.standard.set(value, forKey: Keys.hasCompletedOnboarding)
        },
        displayName: {
            UserDefaults.standard.string(forKey: Keys.displayName)
        },
        setDisplayName: { name in
            UserDefaults.standard.set(name, forKey: Keys.displayName)
        }
    )
}

// MARK: - Mock Implementation

extension UserDefaultsClient {
    static func mock(
        hasCompletedOnboarding: @escaping @Sendable () -> Bool = { false },
        setHasCompletedOnboarding: @escaping @Sendable (Bool) -> Void = { _ in },
        displayName: @escaping @Sendable () -> String? = { nil },
        setDisplayName: @escaping @Sendable (String) -> Void = { _ in }
    ) -> Self {
        UserDefaultsClient(
            hasCompletedOnboarding: hasCompletedOnboarding,
            setHasCompletedOnboarding: setHasCompletedOnboarding,
            displayName: displayName,
            setDisplayName: setDisplayName
        )
    }
}
