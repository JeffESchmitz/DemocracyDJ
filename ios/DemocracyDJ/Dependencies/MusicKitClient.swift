import Dependencies
import Foundation
import MusicKit
import Shared

// Invariant:
// MusicKitClient is owned by HostFeature for playback.
// GuestFeature may use MusicKitClient.search() only (no playback).
// AppFeature must never depend on this client.

/// TCA dependency for MusicKit search and playback.
/// Maps MusicKit.Song to Shared.Song at the dependency boundary.
struct MusicKitClient: Sendable {
    var requestAuthorization: @Sendable () async -> MusicAuthorization.Status
    var search: @Sendable (_ query: String) async throws -> [Shared.Song]
    var play: @Sendable (_ song: Shared.Song) async throws -> Void
    var pause: @Sendable () async -> Void
    var skip: @Sendable () async -> Void
    var playbackStatus: @Sendable () -> AsyncStream<PlaybackStatus>
    var checkSubscription: @Sendable () async -> SubscriptionStatus
}

struct PlaybackStatus: Equatable, Sendable {
    var isPlaying: Bool
    var currentTime: TimeInterval
    var duration: TimeInterval

    static let notPlaying = PlaybackStatus(isPlaying: false, currentTime: 0, duration: 0)
}

struct SubscriptionStatus: Equatable, Sendable {
    var canPlayCatalogContent: Bool
    var canBecomeSubscriber: Bool

    static let unknown = SubscriptionStatus(canPlayCatalogContent: false, canBecomeSubscriber: false)
}

enum MusicKitClientError: Error {
    case songNotFound
    case notAuthorized
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
    static let live: MusicKitClient = {
        MusicKitClient(
            requestAuthorization: {
                await MusicAuthorization.request()
            },
            search: { query in
                var request = MusicCatalogSearchRequest(term: query, types: [MusicKit.Song.self])
                let response = try await request.response()

                return response.songs.map { song in
                    Shared.Song(
                        id: song.id.rawValue,
                        title: song.title,
                        artist: song.artistName,
                        albumArtURL: song.artwork?.url(width: 300, height: 300),
                        duration: song.duration ?? 0
                    )
                }
            },
            play: { song in
                guard MusicAuthorization.currentStatus == .authorized else {
                    throw MusicKitClientError.notAuthorized
                }

                let request = MusicCatalogResourceRequest<MusicKit.Song>(
                    matching: \.id,
                    equalTo: MusicItemID(song.id)
                )
                let response = try await request.response()
                guard let mkSong = response.items.first else {
                    throw MusicKitClientError.songNotFound
                }

                ApplicationMusicPlayer.shared.queue = [mkSong]
                try await ApplicationMusicPlayer.shared.play()
            },
            pause: {
                ApplicationMusicPlayer.shared.pause()
            },
            skip: {
                do {
                    try await ApplicationMusicPlayer.shared.skipToNextEntry()
                } catch {
                    // Ignore playback errors; caller has no error channel.
                }
            },
            playbackStatus: {
                AsyncStream { continuation in
                    func yieldStatus() {
                        let player = ApplicationMusicPlayer.shared
                        let isPlaying = player.state.playbackStatus == .playing
                        let duration: TimeInterval
                        if let song = player.queue.currentEntry?.item as? MusicKit.Song {
                            duration = song.duration ?? 0
                        } else {
                            duration = 0
                        }
                        let status = PlaybackStatus(
                            isPlaying: isPlaying,
                            currentTime: player.playbackTime,
                            duration: duration
                        )
                        continuation.yield(status)
                    }

                    yieldStatus()

                    let task = Task {
                        for await _ in ApplicationMusicPlayer.shared.state.objectWillChange.values {
                            guard !Task.isCancelled else { break }
                            yieldStatus()
                        }
                    }

                    continuation.onTermination = { _ in
                        task.cancel()
                    }
                }
            },
            checkSubscription: {
                await withTaskGroup(of: SubscriptionStatus?.self) { group in
                    group.addTask {
                        for await subscription in MusicSubscription.subscriptionUpdates {
                            return SubscriptionStatus(
                                canPlayCatalogContent: subscription.canPlayCatalogContent,
                                canBecomeSubscriber: subscription.canBecomeSubscriber
                            )
                        }
                        return nil
                    }
                    group.addTask {
                        try? await Task.sleep(for: .seconds(2))
                        return nil
                    }

                    let result = await group.next() ?? nil
                    group.cancelAll()
                    return result ?? .unknown
                }
            }
        )
    }()

    static func mock(
        requestAuthorization: @escaping @Sendable () async -> MusicAuthorization.Status = {
            MusicAuthorization.Status.notDetermined
        },
        search: @escaping @Sendable (String) async throws -> [Shared.Song] = { _ in [] },
        play: @escaping @Sendable (Shared.Song) async throws -> Void = { _ in },
        pause: @escaping @Sendable () async -> Void = {},
        skip: @escaping @Sendable () async -> Void = {},
        playbackStatus: @escaping @Sendable () -> AsyncStream<PlaybackStatus> = {
            AsyncStream { continuation in
                continuation.yield(PlaybackStatus.notPlaying)
            }
        },
        checkSubscription: @escaping @Sendable () async -> SubscriptionStatus = { .unknown }
    ) -> Self {
        MusicKitClient(
            requestAuthorization: requestAuthorization,
            search: search,
            play: play,
            pause: pause,
            skip: skip,
            playbackStatus: playbackStatus,
            checkSubscription: checkSubscription
        )
    }

    static let mock = MusicKitClient.mock()

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
        },
        checkSubscription: { .unknown }
    )
}
