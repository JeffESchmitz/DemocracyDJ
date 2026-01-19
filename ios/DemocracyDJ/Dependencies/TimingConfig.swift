import Dependencies
import Foundation

/// Centralized timing constants for networking and UI operations.
struct TimingConfig: Sendable {
    /// How often the host broadcasts state to connected guests.
    var heartbeatInterval: Duration
    /// Delay before executing search after user stops typing.
    var searchDebounce: Duration
    /// Max time to wait for host to accept connection invitation.
    var connectionTimeout: Duration
    /// How long to display toast notifications before auto-dismiss.
    var toastDismissal: Duration
    /// Timeout for checking Apple Music subscription status.
    var subscriptionCheckTimeout: Duration
}

extension TimingConfig: DependencyKey {
    static let liveValue = TimingConfig(
        heartbeatInterval: .seconds(2),
        searchDebounce: .milliseconds(300),
        connectionTimeout: .seconds(15),
        toastDismissal: .seconds(3),
        subscriptionCheckTimeout: .seconds(2)
    )

    static let testValue = TimingConfig(
        heartbeatInterval: .seconds(2),
        searchDebounce: .milliseconds(300),
        connectionTimeout: .seconds(15),
        toastDismissal: .seconds(3),
        subscriptionCheckTimeout: .seconds(2)
    )

    static let previewValue = TimingConfig(
        heartbeatInterval: .seconds(2),
        searchDebounce: .milliseconds(300),
        connectionTimeout: .seconds(15),
        toastDismissal: .seconds(3),
        subscriptionCheckTimeout: .seconds(2)
    )
}

extension DependencyValues {
    var timingConfig: TimingConfig {
        get { self[TimingConfig.self] }
        set { self[TimingConfig.self] = newValue }
    }
}
