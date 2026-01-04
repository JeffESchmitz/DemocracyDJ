import AVFoundation
import Dependencies
import Foundation
import MediaPlayer
import Shared
import UIKit

struct NowPlayingClient: Sendable {
    var configure: @Sendable () async -> Void
    var updateNowPlaying: @Sendable (_ song: Song?, _ isPlaying: Bool, _ currentTime: TimeInterval, _ duration: TimeInterval) async -> Void
    var remoteCommands: @Sendable () -> AsyncStream<RemoteCommand>
}

enum RemoteCommand: Equatable, Sendable {
    case play
    case pause
    case togglePlayPause
    case nextTrack
    case changePlaybackPosition(TimeInterval)
}

extension NowPlayingClient: DependencyKey {
    static let liveValue: NowPlayingClient = .live
    static let testValue: NowPlayingClient = .mock
    static let previewValue: NowPlayingClient = .preview
}

extension DependencyValues {
    var nowPlayingClient: NowPlayingClient {
        get { self[NowPlayingClient.self] }
        set { self[NowPlayingClient.self] = newValue }
    }
}

extension NowPlayingClient {
    static let live: NowPlayingClient = {
        NowPlayingClient(
            configure: {
                let session = AVAudioSession.sharedInstance()
                do {
                    try session.setCategory(.playback, mode: .default)
                    try session.setActive(true)
                } catch {
                    // Audio session failures are non-fatal for UI.
                }

                NotificationCenter.default.addObserver(
                    forName: AVAudioSession.interruptionNotification,
                    object: nil,
                    queue: .main
                ) { notification in
                    guard let info = notification.userInfo,
                          let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                        return
                    }

                    if type == .began {
                        // Let the caller handle pause via remote command stream.
                        // No direct callback here to avoid side effects in this layer.
                    }
                }
            },
            updateNowPlaying: { song, isPlaying, currentTime, duration in
                let center = MPNowPlayingInfoCenter.default()

                guard let song else {
                    center.nowPlayingInfo = nil
                    return
                }

                var info: [String: Any] = [
                    MPMediaItemPropertyTitle: song.title,
                    MPMediaItemPropertyArtist: song.artist,
                    MPMediaItemPropertyPlaybackDuration: duration,
                    MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
                    MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
                ]

                center.nowPlayingInfo = info

                if let artworkURL = song.albumArtURL {
                    Task {
                        if let (data, _) = try? await URLSession.shared.data(from: artworkURL),
                           let image = UIImage(data: data) {
                            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                            info[MPMediaItemPropertyArtwork] = artwork
                            center.nowPlayingInfo = info
                        }
                    }
                }
            },
            remoteCommands: {
                AsyncStream { continuation in
                    Task { @MainActor in
                        let commandCenter = MPRemoteCommandCenter.shared()

                        commandCenter.playCommand.addTarget { _ in
                            continuation.yield(.play)
                            return .success
                        }

                        commandCenter.pauseCommand.addTarget { _ in
                            continuation.yield(.pause)
                            return .success
                        }

                        commandCenter.togglePlayPauseCommand.addTarget { _ in
                            continuation.yield(.togglePlayPause)
                            return .success
                        }

                        commandCenter.nextTrackCommand.addTarget { _ in
                            continuation.yield(.nextTrack)
                            return .success
                        }

                        commandCenter.changePlaybackPositionCommand.addTarget { event in
                            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                                return .commandFailed
                            }
                            continuation.yield(.changePlaybackPosition(event.positionTime))
                            return .success
                        }

                        commandCenter.playCommand.isEnabled = true
                        commandCenter.pauseCommand.isEnabled = true
                        commandCenter.togglePlayPauseCommand.isEnabled = true
                        commandCenter.nextTrackCommand.isEnabled = true
                        commandCenter.previousTrackCommand.isEnabled = false
                        commandCenter.changePlaybackPositionCommand.isEnabled = true

                        continuation.onTermination = { _ in
                            Task { @MainActor in
                                let commandCenter = MPRemoteCommandCenter.shared()
                                commandCenter.playCommand.removeTarget(nil)
                                commandCenter.pauseCommand.removeTarget(nil)
                                commandCenter.togglePlayPauseCommand.removeTarget(nil)
                                commandCenter.nextTrackCommand.removeTarget(nil)
                                commandCenter.changePlaybackPositionCommand.removeTarget(nil)
                            }
                        }
                    }
                }
            }
        )
    }()

    static func mock(
        configure: @escaping @Sendable () async -> Void = {},
        updateNowPlaying: @escaping @Sendable (Song?, Bool, TimeInterval, TimeInterval) async -> Void = { _, _, _, _ in },
        remoteCommands: @escaping @Sendable () -> AsyncStream<RemoteCommand> = { AsyncStream { $0.finish() } }
    ) -> NowPlayingClient {
        NowPlayingClient(
            configure: configure,
            updateNowPlaying: updateNowPlaying,
            remoteCommands: remoteCommands
        )
    }

    static let mock = NowPlayingClient.mock()

    static let preview = mock
}
