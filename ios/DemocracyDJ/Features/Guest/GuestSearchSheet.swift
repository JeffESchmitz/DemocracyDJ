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
                .accessibilityIdentifier("song_search_field")

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
#if DEBUG
                ToolbarItem(placement: .primaryAction) {
                    Button("Debug Recs") {
                        store.send(.debugLoadRecommendations)
                    }
                    .tint(.orange)
                }
#endif
            }
            .onAppear {
                isSearchFocused = true
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.searchQuery.count < 2 {
            recommendationsContent
        } else if let error = store.searchError {
            ContentUnavailableView(
                "Search Error",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
            .padding()
        } else if store.isSearching {
            ProgressView()
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
                Button {
                    store.send(.songSelected(song))
                } label: {
                    songRow(song)
                }
                .buttonStyle(.plain)
                .disabled(isDuplicateSong(song))
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var recommendationsContent: some View {
        if store.isLoadingRecommendations {
            ProgressView("Loading recommendations...")
                .padding()
        } else if let error = store.recommendationsError {
            VStack(spacing: 12) {
                ContentUnavailableView(
                    "Recommendations Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )

                Button("Retry") {
                    store.send(.loadRecommendations)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        } else if store.recommendations.isEmpty {
            ContentUnavailableView(
                "Search for Songs",
                systemImage: "magnifyingglass",
                description: Text("Type at least 2 characters.")
            )
            .padding()
        } else {
            recommendationsList
        }
    }

    private var recommendationsList: some View {
        List {
            ForEach(store.recommendations) { section in
                Section(section.title) {
                    ForEach(section.songs) { song in
                        Button {
                            store.send(.songSelected(song))
                        } label: {
                            songRow(song)
                        }
                        .buttonStyle(.plain)
                        .disabled(isDuplicateSong(song))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func songRow(_ song: Song) -> some View {
        let isDuplicate = isDuplicateSong(song)

        return HStack(spacing: 12) {
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

#Preview("Recommendations") {
    GuestSearchSheet(
        store: Store(
            initialState: GuestFeature.State(
                myPeer: Peer(name: "Guest"),
                hostSnapshot: HostSnapshot(
                    nowPlaying: .previewSong,
                    queue: .previewQueue,
                    connectedPeers: [],
                    isPlaying: true
                ),
                searchQuery: "",
                recommendations: .previewRecommendations
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
        connectedPeers: [],
        isPlaying: true
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
