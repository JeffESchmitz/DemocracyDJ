import ComposableArchitecture
import Shared
import SwiftUI

struct GuestSearchSheet: View {
    @Bindable var store: StoreOf<GuestFeature>
    @FocusState private var isSearchFocused: Bool

    var body: some View {
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
                .focused($isSearchFocused)
                .textInputAutocapitalization(.never)

                content
            }
            .navigationTitle("Suggest a Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.send(.dismissSearch)
                    }
                }
            }
            .onAppear {
                isSearchFocused = true
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let error = store.searchError {
            ContentUnavailableView(
                "Search Error",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
            .padding()
        } else if store.isSearching {
            ProgressView()
                .padding()
        } else if store.searchQuery.count < 2 {
            ContentUnavailableView(
                "Search for Songs",
                systemImage: "magnifyingglass",
                description: Text("Type at least 2 characters.")
            )
            .padding()
        } else if store.searchResults.isEmpty {
            ContentUnavailableView(
                "No Results",
                systemImage: "music.note",
                description: Text("Try a different search.")
            )
            .padding()
        } else {
            List(store.searchResults) { song in
                let isDuplicate = isDuplicateSong(song)

                Button {
                    store.send(.songSelected(song))
                } label: {
                    HStack(spacing: 12) {
                        AlbumArtworkView(
                            url: song.albumArtURL,
                            title: song.title,
                            size: 50,
                            cornerRadius: 8
                        )

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
    }

    private func isDuplicateSong(_ song: Song) -> Bool {
        if store.hostSnapshot?.nowPlaying?.id == song.id {
            return true
        }
        return store.hostSnapshot?.queue.contains(where: { $0.id == song.id }) ?? false
    }
}

#Preview("Empty State") {
    GuestSearchSheet(
        store: Store(
            initialState: GuestFeature.State(
                myPeer: Peer(name: "Guest"),
                searchQuery: "",
                searchResults: [],
                isSearching: false
            )
        ) {
            GuestFeature()
        }
    )
}

#Preview("Searching") {
    GuestSearchSheet(
        store: Store(
            initialState: GuestFeature.State(
                myPeer: Peer(name: "Guest"),
                searchQuery: "ha",
                searchResults: [],
                isSearching: true
            )
        ) {
            GuestFeature()
        }
    )
}

#Preview("With Results") {
    let snapshot = HostSnapshot(
        nowPlaying: .previewSong,
        queue: .previewQueue,
        connectedPeers: []
    )

    return GuestSearchSheet(
        store: Store(
            initialState: GuestFeature.State(
                myPeer: Peer(name: "Guest"),
                hostSnapshot: snapshot,
                searchQuery: "lev",
                searchResults: [.previewSong, .previewSong2, .previewSong3],
                isSearching: false
            )
        ) {
            GuestFeature()
        }
    )
}

#Preview("Error") {
    GuestSearchSheet(
        store: Store(
            initialState: GuestFeature.State(
                myPeer: Peer(name: "Guest"),
                searchQuery: "ha",
                searchResults: [],
                isSearching: false,
                searchError: "Network unavailable"
            )
        ) {
            GuestFeature()
        }
    )
}
