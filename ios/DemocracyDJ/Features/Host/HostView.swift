import ComposableArchitecture
import Shared
import SwiftUI

// This is a reference implementation for HostView.
// Note: lifecycle actions (startHosting/stopHosting) are intentionally not triggered by the view.
// The view only renders state and emits user intent.

struct HostView: View {
    @Bindable var store: StoreOf<HostFeature>

    var body: some View {
        GeometryReader { proxy in
            let layout = HostLayout(availableHeight: proxy.size.height)

            VStack(spacing: 0) {
                // MARK: - Top Section: Now Playing (adaptive sizing)
                VStack(spacing: layout.sectionSpacing) {
#if DEBUG
                    debugButtons(layout: layout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
#endif
                    if let song = store.nowPlaying {
                        AlbumArtworkView(
                            url: song.albumArtURL,
                            title: song.title,
                            size: layout.artworkSize,
                            cornerRadius: 12
                        )
                        .padding(.horizontal, layout.horizontalPadding)

                        VStack(spacing: 8) {
                            Text(song.title)
                                .font(.system(size: layout.titleFontSize, weight: .bold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .accessibilityLabel("Now playing: \(song.title)")

                            Text(song.artist)
                                .font(.system(size: layout.subtitleFontSize))
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Artist: \(song.artist)")
                        }

                        VStack(spacing: 4) {
                            ProgressView(
                                value: store.playbackStatus.currentTime,
                                total: max(store.playbackStatus.duration, 1)
                            )
                            .progressViewStyle(.linear)

                            HStack {
                                Text(formatTime(store.playbackStatus.currentTime))
                                Spacer()
                                Text(formatTime(store.playbackStatus.duration))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, layout.horizontalPadding)

                        // Controls (Active)
                        HStack(spacing: 40) {
                            Button {
                                if store.isPlaying {
                                    store.send(.pauseTapped)
                                } else {
                                    store.send(.playTapped)
                                }
                            } label: {
                                Image(systemName: store.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: layout.playControlSize))
                                    .foregroundStyle(.primary)
                            }
                            .disabled(!store.canPlay)
                            .accessibilityLabel(store.isPlaying ? "Pause" : "Play")
                            .accessibilityHint(store.isPlaying ? "Pauses playback" : "Resumes playback")

                            Button {
                                store.send(.skipTapped)
                            } label: {
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: layout.skipControlSize))
                                    .foregroundStyle(.primary)
                            }
                            .accessibilityLabel("Skip song")
                        }
                        .padding(.top, 10)

                        if store.musicAuthorizationStatus == .authorized,
                           !store.subscriptionStatus.canPlayCatalogContent {
                            VStack(spacing: 4) {
                                Text("Apple Music subscription required")
                                    .font(.caption)
                                    .foregroundStyle(.orange)

                                if store.subscriptionStatus.canBecomeSubscriber,
                                   let subscribeURL = URL(string: "https://music.apple.com/subscribe") {
                                    Link("Subscribe to Apple Music", destination: subscribeURL)
                                        .font(.caption)
                                }
                            }
                            .padding(.top, 8)
                        }
                    } else {
                        // Empty State / Nothing Playing
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: layout.artworkSize, height: layout.artworkSize)
                            .overlay {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: layout.emptyStateIconSize))
                                    .foregroundStyle(.tertiary)
                            }
                            .cornerRadius(12)
                            .padding(.horizontal, layout.horizontalPadding)

                        Text("Nothing Playing")
                            .font(.system(size: layout.titleFontSize))
                            .foregroundStyle(.secondary)
                            .padding(.top, 20)
                            .accessibilityLabel("Nothing playing")

                        // Controls (Disabled)
                        HStack(spacing: 40) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: layout.playControlSize))
                            Image(systemName: "forward.end.fill")
                                .font(.system(size: layout.skipControlSize))
                        }
                        .foregroundStyle(.tertiary)
                        .padding(.top, 10)
                        .accessibilityLabel("Controls disabled")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: proxy.size.height * layout.topMaxHeightFraction, alignment: .top)
                .padding(.vertical, layout.verticalPadding)
                .background(Color(uiColor: .systemBackground))
                .clipped()

                Divider()

                // MARK: - Bottom Section: Up Next
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Up Next")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)

                        Spacer()

                        Button {
                            store.send(.addSongTapped)
                        } label: {
                            Label("Add", systemImage: "plus.circle.fill")
                                .font(.subheadline)
                        }
                        .disabled(store.musicAuthorizationStatus != .authorized)
                        .accessibilityIdentifier("add_song_button")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground))

                    List {
                        // Render queue EXACTLY as given. Do not sort.
                        ForEach(Array(store.queue.enumerated()), id: \.element.id) { index, item in
                            HStack(spacing: 16) {
                                // Position Number
                                Text("\(index + 1)")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30)
                                    .accessibilityLabel("Position \(index + 1)")

                                // Text-Only Info
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.song.title)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .lineLimit(1)

                                    Text("Added by \(item.addedBy.name)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                // Vote Badge (Source: item.voters.count)
                                HStack(spacing: 4) {
                                    Image(systemName: "hand.thumbsup.fill")
                                        .font(.caption)
                                    Text("\(item.voters.count)")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .monospacedDigit()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.1))
                                .foregroundStyle(.primary)
                                .clipShape(Capsule())
                                .accessibilityLabel("\(item.voters.count) votes")
                            }
                            .padding(.vertical, 4)
                            .listRowSeparator(.hidden)
                            .accessibilityIdentifier("song_row_\(item.id)")
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    store.send(.removeSongTapped(id: item.id))
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.send(.removeSongTapped(id: item.id))
                                } label: {
                                    Label("Remove from Queue", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .accessibilityIdentifier("shared_queue_view")
                    .frame(minHeight: layout.queueMinHeight)
                }
                .layoutPriority(1)
            }
        }
        // MARK: - Status Badge
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(store.isHosting ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)

                    Text("HOST")
                        .font(.caption2)
                        .fontWeight(.bold)

                    Text("Peers: \(store.connectedPeers.count)")
                        .font(.caption2)
                }
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .accessibilityElement(children: .combine)
                .accessibilityLabel(statusLabel)

                Button {
                    store.send(.exitTapped)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Exit session")
            }
            .padding()
        }
        .sheet(
            isPresented: Binding(
                get: { store.isSearchSheetPresented },
                set: { isPresented in
                    if !isPresented {
                        store.send(.dismissSearch)
                    }
                }
            )
        ) {
            NavigationStack {
                VStack(spacing: 0) {
                    TextField(
                        "Search Apple Music",
                        text: Binding(
                            get: { store.searchQuery },
                            set: { store.send(.searchQueryChanged($0)) }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .padding()

                    if store.isSearching {
                        ProgressView()
                            .padding()
                    }

                    List(store.searchResults) { song in
                        let isDuplicate = store.queue.contains(where: { $0.id == song.id })
                            || store.nowPlaying?.id == song.id

                        Button {
                            store.send(.songSelected(song))
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(song.title)
                                        .font(.body)
                                        .lineLimit(1)
                                    Text(song.artist)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if isDuplicate {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isDuplicate)
                    }
                    .listStyle(.plain)
                }
                .navigationTitle("Add Song")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            store.send(.dismissSearch)
                        }
                    }
                }
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var statusLabel: String {
        if store.isHosting {
            return "Hosting active, \(store.connectedPeers.count) peers connected"
        }
        return "Hosting inactive, \(store.connectedPeers.count) peers connected"
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(Int(seconds.rounded()), 0)
        let minutes = totalSeconds / 60
        let remainder = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

#if DEBUG
    @ViewBuilder
    private func debugButtons(layout: HostLayout) -> some View {
        if layout.isCompact {
            VStack(spacing: layout.debugButtonSpacing) {
                debugRequestAuthButton(layout: layout)
                debugSetNowPlayingButton(layout: layout)
            }
        } else {
            HStack(spacing: layout.debugButtonSpacing) {
                debugRequestAuthButton(layout: layout)
                debugSetNowPlayingButton(layout: layout)
            }
        }
    }

    private func debugRequestAuthButton(layout: HostLayout) -> some View {
        Button("DEBUG: Music Auth") {
            store.send(.requestMusicAuthorization)
        }
        .buttonStyle(.bordered)
        .tint(.orange)
        .font(.caption2)
        .controlSize(.mini)
    }

    private func debugSetNowPlayingButton(layout: HostLayout) -> some View {
        Button("DEBUG: Now Playing") {
            store.send(._debugSetNowPlaying)
        }
        .buttonStyle(.bordered)
        .tint(.blue)
        .font(.caption2)
        .controlSize(.mini)
    }
#endif
}

private struct HostLayout {
    let availableHeight: CGFloat

    var isCompact: Bool { availableHeight < 700 }
    var isRegular: Bool { availableHeight < 850 }

    var artworkSize: CGFloat {
        if isCompact { return 180 }
        if isRegular { return 260 }
        return 300
    }

    var titleFontSize: CGFloat {
        if isCompact { return 20 }
        if isRegular { return 26 }
        return 28
    }

    var subtitleFontSize: CGFloat {
        if isCompact { return 15 }
        if isRegular { return 19 }
        return 20
    }

    var playControlSize: CGFloat {
        if isCompact { return 52 }
        if isRegular { return 64 }
        return 70
    }

    var skipControlSize: CGFloat {
        if isCompact { return 36 }
        if isRegular { return 46 }
        return 50
    }

    var emptyStateIconSize: CGFloat {
        if isCompact { return 44 }
        if isRegular { return 56 }
        return 60
    }

    var sectionSpacing: CGFloat {
        if isCompact { return 14 }
        if isRegular { return 18 }
        return 20
    }

    var verticalPadding: CGFloat {
        if isCompact { return 8 }
        if isRegular { return 12 }
        return 16
    }

    var horizontalPadding: CGFloat {
        if isCompact { return 24 }
        if isRegular { return 32 }
        return 40
    }

    var queueMinHeight: CGFloat {
        if isCompact { return 64 }
        if isRegular { return 100 }
        return 160
    }

    var topMaxHeightFraction: CGFloat {
        if isCompact { return 0.70 }
        if isRegular { return 0.70 }
        return 0.72
    }

    var debugButtonSpacing: CGFloat {
        if isCompact { return 4 }
        if isRegular { return 6 }
        return 8
    }
}

// MARK: - Preview

#Preview("Subscribed - Playing") {
    HostView(
        store: Store(
            initialState: HostFeature.State(
                myPeer: Peer(name: "Dad's iPhone"),
                nowPlaying: .previewSong,
                queue: .previewQueue,
                connectedPeers: [Peer(name: "Mom"), Peer(name: "Son")],
                isHosting: true,
                isPlaying: true,
                playbackStatus: PlaybackStatus(isPlaying: true, currentTime: 42, duration: 354),
                musicAuthorizationStatus: .authorized,
                subscriptionStatus: .subscribed
            )
        ) {
            HostFeature()
        }
    )
}

#Preview("Not Subscribed - Can Subscribe") {
    HostView(
        store: Store(
            initialState: HostFeature.State(
                myPeer: Peer(name: "Dad's iPhone"),
                nowPlaying: .previewSong,
                queue: .previewQueue,
                connectedPeers: [],
                isHosting: true,
                musicAuthorizationStatus: .authorized,
                subscriptionStatus: .notSubscribed
            )
        ) {
            HostFeature()
        }
    )
}

#Preview("Not Authorized") {
    HostView(
        store: Store(
            initialState: HostFeature.State(
                myPeer: Peer(name: "Dad's iPhone"),
                nowPlaying: .previewSong,
                queue: .previewQueue,
                connectedPeers: [],
                isHosting: true,
                musicAuthorizationStatus: .notDetermined,
                subscriptionStatus: .unknown
            )
        ) {
            HostFeature()
        }
    )
}

#Preview("Nothing Playing") {
    HostView(
        store: Store(
            initialState: HostFeature.State(
                myPeer: Peer(name: "Dad's iPhone"),
                nowPlaying: nil,
                queue: [],
                connectedPeers: [],
                isHosting: true,
                musicAuthorizationStatus: .authorized,
                subscriptionStatus: .subscribed
            )
        ) {
            HostFeature()
        }
    )
}
