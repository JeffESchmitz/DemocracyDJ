import Dependencies
import Foundation
import MusicKit
import Shared

// Invariant:
// MusicKitClient MUST only be accessed by HostFeature.
// GuestFeature and AppFeature must never depend on this client.

/// TCA dependency for MusicKit search and playback.
/// Maps MusicKit.Song to Shared.Song at the dependency boundary.
struct MusicKitClient: Sendable {
    var requestAuthorization: @Sendable () async -> MusicAuthorization.Status
    var search: @Sendable (_ query: String) async throws -> [Shared.Song]
    var play: @Sendable (_ song: Shared.Song) async throws -> Void
    var pause: @Sendable () async -> Void
    var skip: @Sendable () async -> Void
    var playbackStatus: @Sendable () -> AsyncStream<PlaybackStatus>
}

struct PlaybackStatus: Equatable, Sendable {
    var isPlaying: Bool
    var currentTime: TimeInterval
    var duration: TimeInterval

    static let notPlaying = PlaybackStatus(isPlaying: false, currentTime: 0, duration: 0)
}

extension MusicKitClient: DependencyKey {
    static let liveValue: MusicKitClient = .live
    static let testValue: MusicKitClient = .mock
    static let previewValue: MusicKitClient = .preview
}

extension DependencyValues {
    var musicKitClient: MusicKitClient {
        get { self[MusicKitClient.self] }
        set { self[MusicKitClient.self] = newValue }
    }
}

extension MusicKitClient {
    // Placeholder for future live implementation.
    static let live: MusicKitClient = .mock

    static let mock = MusicKitClient(
        requestAuthorization: { MusicAuthorization.Status.notDetermined },
        search: { _ in [] },
        play: { _ in },
        pause: { },
        skip: { },
        playbackStatus: {
            AsyncStream { continuation in
                continuation.yield(PlaybackStatus.notPlaying)
            }
        }
    )

    static let preview = MusicKitClient(
        requestAuthorization: { MusicAuthorization.Status.notDetermined },
        search: { _ in [] },
        play: { _ in },
        pause: { },
        skip: { },
        playbackStatus: {
            AsyncStream { continuation in
                continuation.yield(PlaybackStatus.notPlaying)
            }
        }
    )
}
