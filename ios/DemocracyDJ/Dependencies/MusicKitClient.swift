import Dependencies
import Foundation
import MusicKit
import Shared

// Invariant:
// MusicKitClient is owned by HostFeature for playback.
// GuestFeature may use MusicKitClient.search() and recommendations only (no playback).
// AppFeature must never depend on this client.

/// TCA dependency for MusicKit search and playback.
/// Maps MusicKit.Song to Shared.Song at the dependency boundary.
struct MusicKitClient: Sendable {
    var requestAuthorization: @Sendable () async -> MusicAuthorization.Status
    var search: @Sendable (_ query: String) async throws -> [Shared.Song]
    var recommendations: @Sendable () async throws -> [RecommendationSection]
    var play: @Sendable (_ song: Shared.Song) async throws -> Void
    var pause: @Sendable () async -> Void
    var skip: @Sendable () async -> Void
    var seek: @Sendable (_ time: TimeInterval) async -> Void
    var playbackStatus: @Sendable () -> AsyncStream<PlaybackStatus>
    var checkSubscription: @Sendable () async -> SubscriptionStatus
}

struct PlaybackStatus: Equatable, Sendable {
    var isPlaying: Bool
    var currentTime: TimeInterval
    var duration: TimeInterval

    static let notPlaying = PlaybackStatus(isPlaying: false, currentTime: 0, duration: 0)
}

struct RecommendationSection: Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let songs: [Shared.Song]
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
            recommendations: {
                guard MusicAuthorization.currentStatus == .authorized else {
                    return []
                }

                do {
                    var request = MusicPersonalRecommendationsRequest()
                    request.limit = 5
                    let response = try await request.response()
                    var sections: [RecommendationSection] = []

                    for recommendation in response.recommendations {
                        for playlist in recommendation.playlists {
                            guard sections.count < 5 else {
                                break
                            }

                            let detailedPlaylist = try await playlist.with([.tracks])
                            let tracks = detailedPlaylist.tracks ?? []
                            let songs = tracks.prefix(10).compactMap { entry -> Shared.Song? in
                                guard case let .song(mkSong) = entry else {
                                    return nil
                                }
                                return Shared.Song(
                                    id: mkSong.id.rawValue,
                                    title: mkSong.title,
                                    artist: mkSong.artistName,
                                    albumArtURL: mkSong.artwork?.url(width: 300, height: 300),
                                    duration: mkSong.duration ?? 0
                                )
                            }

                            if !songs.isEmpty {
                                sections.append(RecommendationSection(
                                    id: playlist.id.rawValue,
                                    title: playlist.name,
                                    songs: songs
                                ))
                            }
                        }

                        for album in recommendation.albums {
                            guard sections.count < 5 else {
                                break
                            }

                            let detailedAlbum = try await album.with([.tracks])
                            let tracks = detailedAlbum.tracks ?? []
                            let songs = tracks.prefix(10).map { mkSong in
                                Shared.Song(
                                    id: mkSong.id.rawValue,
                                    title: mkSong.title,
                                    artist: mkSong.artistName,
                                    albumArtURL: mkSong.artwork?.url(width: 300, height: 300),
                                    duration: mkSong.duration ?? 0
                                )
                            }

                            if !songs.isEmpty {
                                sections.append(RecommendationSection(
                                    id: album.id.rawValue,
                                    title: album.title,
                                    songs: songs
                                ))
                            }
                        }

                        if sections.count >= 5 {
                            break
                        }
                    }

                    return sections
                } catch let error as URLError {
                    throw error
                } catch {
                    return []
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
            seek: { time in
                ApplicationMusicPlayer.shared.playbackTime = time
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
        recommendations: @escaping @Sendable () async throws -> [RecommendationSection] = { [] },
        play: @escaping @Sendable (Shared.Song) async throws -> Void = { _ in },
        pause: @escaping @Sendable () async -> Void = {},
        skip: @escaping @Sendable () async -> Void = {},
        seek: @escaping @Sendable (TimeInterval) async -> Void = { _ in },
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
            recommendations: recommendations,
            play: play,
            pause: pause,
            skip: skip,
            seek: seek,
            playbackStatus: playbackStatus,
            checkSubscription: checkSubscription
        )
    }

    static let mock = MusicKitClient.mock()

    static let preview = MusicKitClient(
        requestAuthorization: { MusicAuthorization.Status.notDetermined },
        search: { _ in [] },
        recommendations: { [] },
        play: { _ in },
        pause: { },
        skip: { },
        seek: { _ in },
        playbackStatus: {
            AsyncStream { continuation in
                continuation.yield(PlaybackStatus.notPlaying)
            }
        },
        checkSubscription: { .unknown }
    )
}
