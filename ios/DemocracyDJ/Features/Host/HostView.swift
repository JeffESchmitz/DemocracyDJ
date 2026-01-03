import ComposableArchitecture
import Shared
import SwiftUI

// This is a reference implementation for HostView.
// Note: lifecycle actions (startHosting/stopHosting) are intentionally not triggered by the view.
// The view only renders state and emits user intent.

struct HostView: View {
    @Bindable var store: StoreOf<HostFeature>

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Section: Now Playing (60% approx via layoutPriority)
            VStack(spacing: 20) {
                if let song = store.nowPlaying {
                    AlbumArtworkView(
                        url: song.albumArtURL,
                        title: song.title,
                        size: 300,
                        cornerRadius: 12
                    )
                    .padding(.horizontal, 40)

                    VStack(spacing: 8) {
                        Text(song.title)
                            .font(.system(size: 28, weight: .bold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .accessibilityLabel("Now playing: \(song.title)")

                        Text(song.artist)
                            .font(.title3)
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
                    .padding(.horizontal, 40)

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
                                .font(.system(size: 70))
                                .foregroundStyle(.primary)
                        }
                        .disabled(!store.canPlay)
                        .accessibilityLabel(store.isPlaying ? "Pause" : "Play")
                        .accessibilityHint(store.isPlaying ? "Pauses playback" : "Resumes playback")

                        Button {
                            store.send(.skipTapped)
                        } label: {
                            Image(systemName: "forward.end.fill")
                                .font(.system(size: 50))
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
#if DEBUG
                    Button("DEBUG: Request Music Authorization") {
                        store.send(.requestMusicAuthorization)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .padding(.top, 16)

                    Button("DEBUG: Set Now Playing") {
                        store.send(._debugSetNowPlaying)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .padding(.top, 8)
#endif

                } else {
                    // Empty State / Nothing Playing
                    Rectangle()
                        .fill(Color.secondary.opacity(0.1))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 60))
                                .foregroundStyle(.tertiary)
                        }
                        .cornerRadius(12)
                        .padding(.horizontal, 40)

                    Text("Nothing Playing")
                        .font(.title)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                        .accessibilityLabel("Nothing playing")

                    // Controls (Disabled)
                    HStack(spacing: 40) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 70))
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 50))
                    }
                    .foregroundStyle(.tertiary)
                    .padding(.top, 10)
                    .accessibilityLabel("Controls disabled")
#if DEBUG
                    Button("DEBUG: Request Music Authorization") {
                        store.send(.requestMusicAuthorization)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .padding(.top, 16)

                    Button("DEBUG: Set Now Playing") {
                        store.send(._debugSetNowPlaying)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .padding(.top, 8)
#endif
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
            .background(Color(uiColor: .systemBackground))
            .layoutPriority(1.5)

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
                    }
                }
                .listStyle(.plain)
            }
            .layoutPriority(1)
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
}

// MARK: - Preview

#Preview {
    HostView(
        store: Store(
            initialState: HostFeature.State(
                myPeer: Peer(name: "Dad's iPhone"),
                nowPlaying: Song(
                    id: "1",
                    title: "Bohemian Rhapsody",
                    artist: "Queen",
                    albumArtURL: nil,
                    duration: 354
                ),
                queue: [
                    QueueItem(
                        id: "2",
                        song: Song(
                            id: "2",
                            title: "Hotel California",
                            artist: "Eagles",
                            albumArtURL: nil,
                            duration: 391
                        ),
                        addedBy: Peer(name: "Dad"),
                        voters: Set([
                            UUID().uuidString,
                            UUID().uuidString,
                            UUID().uuidString
                        ])
                    ),
                    QueueItem(
                        id: "3",
                        song: Song(
                            id: "3",
                            title: "Levitating",
                            artist: "Dua Lipa",
                            albumArtURL: nil,
                            duration: 203
                        ),
                        addedBy: Peer(name: "Teenager"),
                        voters: Set([
                            UUID().uuidString
                        ])
                    )
                ],
                connectedPeers: [Peer(name: "Mom"), Peer(name: "Son")],
                isHosting: true
            )
        ) {
            HostFeature()
        }
    )
}
