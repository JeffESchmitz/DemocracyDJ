import ComposableArchitecture
import Shared
import SwiftUI
import UIKit

struct GuestView: View {
    @Bindable var store: StoreOf<GuestFeature>
    @State private var isSuggestSongExpanded = true

    var body: some View {
        VStack(spacing: 0) {
#if DEBUG
            Button("DEBUG: Load Sample Queue") {
                store.send(.debugLoadSample)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.top, 8)
#endif

            connectionStatusSection
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded {
                    collapseSuggestSong()
                })

            Divider()

            switch store.connectionStatus {
            case .disconnected, .browsing, .connecting, .failed:
                browsingSection

            case .connected:
                connectedSection
            }

            Divider()

            suggestSongSection
        }
        .background(Color(uiColor: .systemBackground))
        .sheet(
            isPresented: Binding(
                get: { store.showSearchSheet },
                set: { isPresented in
                    if !isPresented {
                        store.send(.dismissSearch)
                    }
                }
            )
        ) {
            GuestSearchSheet(store: store)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                Text(statusText)
                    .font(.headline)

                Spacer()

                Button {
                    store.send(.exitTapped)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Exit session")
            }

            if case let .connected(host) = store.connectionStatus {
                Text("Host: \(host.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if case let .failed(reason) = store.connectionStatus {
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }

    private var browsingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Nearby Parties")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 12)

            List {
                ForEach(store.availableHosts) { host in
                    Button {
                        store.send(.connectToHost(host))
                    } label: {
                        HStack {
                            Text(host.name)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text("Tap to Join")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(isConnecting)
                }

                if store.availableHosts.isEmpty {
                    Text(isConnecting ? "Connecting..." : "No nearby hosts")
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.plain)
            .disabled(isConnecting)
        }
    }

    private var connectedSection: some View {
        VStack(spacing: 0) {
            nowPlayingSection

            Divider()

            voteQueueSection
        }
    }

    private var nowPlayingSection: some View {
        VStack(spacing: 16) {
            Text("Now Playing")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let song = store.hostSnapshot?.nowPlaying {
                AlbumArtworkView(
                    url: song.albumArtURL,
                    title: song.title,
                    size: nowPlayingArtworkSize,
                    cornerRadius: 12
                )
                    .padding(.horizontal, 40)

                VStack(spacing: 4) {
                    Text(song.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if store.hostSnapshot?.isPlaying == false {
                        Text("Paused")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 50))
                            .foregroundStyle(.tertiary)
                    }
                    .cornerRadius(12)
                    .padding(.horizontal, 40)

                Text("Nothing Playing")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            collapseSuggestSong()
        })
    }

    private var voteQueueSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Queue")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 12)

            if let queue = store.hostSnapshot?.queue {
                GuestQueueView(
                    queue: queue,
                    pendingVotes: store.pendingVotes,
                    myPeerID: store.myPeer?.id,
                    onVote: { songID in
                        store.send(.voteTapped(songID: songID))
                    }
                )
            } else {
                Text("Waiting for host...")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }

    private var suggestSongSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isSuggestSongExpanded.toggle()
            } label: {
                HStack {
                    Text("Suggest a Song")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isSuggestSongExpanded ? 0 : -90))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }
            .buttonStyle(.plain)

            if isSuggestSongExpanded {
                List {
                    Button {
                        store.send(.searchButtonTapped)
                    } label: {
                        HStack {
                            Text("Search Apple Music")
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("add_song_button")
                }
                .listStyle(.plain)
            }
        }
    }

    private var isConnecting: Bool {
        if case .connecting = store.connectionStatus {
            return true
        }
        return false
    }

    private var nowPlayingArtworkSize: CGFloat {
        min(UIScreen.main.bounds.width - 80, 260)
    }

    private var isConnected: Bool {
        if case .connected = store.connectionStatus {
            return true
        }
        return false
    }

    private var statusColor: Color {
        switch store.connectionStatus {
        case .disconnected:
            return .red
        case .browsing:
            return .orange
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .failed:
            return .red
        }
    }

    private var statusText: String {
        switch store.connectionStatus {
        case .disconnected:
            return "Disconnected"
        case .browsing:
            return "Browsing"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .failed:
            return "Connection Failed"
        }
    }

    private func collapseSuggestSong() {
        isSuggestSongExpanded = false
    }
}

#Preview {
    let host = Peer(id: "host", name: "DJ")
    let snapshot = HostSnapshot(
        nowPlaying: Song(
            id: "song-1",
            title: "Blinding Lights",
            artist: "The Weeknd",
            albumArtURL: nil,
            duration: 200
        ),
        queue: [
            QueueItem(
                id: "song-2",
                song: Song(
                    id: "song-2",
                    title: "Levitating",
                    artist: "Dua Lipa",
                    albumArtURL: nil,
                    duration: 203
                ),
                addedBy: Peer(name: "Alex"),
                voters: ["a", "b"]
            ),
            QueueItem(
                id: "song-3",
                song: Song(
                    id: "song-3",
                    title: "Watermelon Sugar",
                    artist: "Harry Styles",
                    albumArtURL: nil,
                    duration: 174
                ),
                addedBy: Peer(name: "Sam"),
                voters: ["c"]
            )
        ],
        connectedPeers: [Peer(name: "Alex"), Peer(name: "Sam")],
        isPlaying: true
    )

    GuestView(
        store: Store(
            initialState: GuestFeature.State(
                myPeer: Peer(id: "guest", name: "Guest"),
                connectionStatus: .connected(host: host),
                hostSnapshot: snapshot,
                pendingVotes: ["song-3"],
                availableHosts: []
            )
        ) {
            GuestFeature()
        }
    )
}
