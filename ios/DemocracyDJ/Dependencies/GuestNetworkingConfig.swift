import Dependencies
import Foundation

struct GuestNetworkingConfig: Sendable {
    /// How long to wait without host activity before assuming disconnected.
    var inactivityTimeout: TimeInterval
    /// How often to check for host activity.
    var checkInterval: TimeInterval
}

extension GuestNetworkingConfig: DependencyKey {
    static let liveValue = GuestNetworkingConfig(
        inactivityTimeout: 5,
        checkInterval: 1
    )

    static let testValue = GuestNetworkingConfig(
        inactivityTimeout: 0.5,
        checkInterval: 0.1
    )

    static let previewValue = GuestNetworkingConfig(
        inactivityTimeout: 3,
        checkInterval: 1
    )
}

extension DependencyValues {
    var guestNetworkingConfig: GuestNetworkingConfig {
        get { self[GuestNetworkingConfig.self] }
        set { self[GuestNetworkingConfig.self] = newValue }
    }
}
