import Shared
import SwiftUI

struct GuestQueueView: View {
    let queue: [QueueItem]
    let pendingVotes: Set<String>
    let myPeerID: String?
    let onVote: (String) -> Void

    var body: some View {
        if queue.isEmpty {
            Text("No songs yet")
                .foregroundStyle(.secondary)
                .padding()
        } else {
            List {
                ForEach(Array(queue.enumerated()), id: \.element.id) { index, item in
                    let hasVoted = item.voters.contains(myPeerID ?? "") || pendingVotes.contains(item.id)

                    GuestQueueItemRow(
                        item: item,
                        position: index + 1,
                        hasVoted: hasVoted,
                        onVote: {
                            onVote(item.id)
                        }
                    )
                    .listRowSeparator(.hidden)
                    .accessibilityIdentifier("song_row_\(item.id)")
                }
            }
            .listStyle(.plain)
            .accessibilityIdentifier("shared_queue_view")
        }
    }
}

#Preview {
    GuestQueueView(
        queue: [
            QueueItem(
                id: "song-1",
                song: Song(
                    id: "song-1",
                    title: "Levitating",
                    artist: "Dua Lipa",
                    albumArtURL: nil,
                    duration: 203
                ),
                addedBy: Peer(name: "Alex"),
                voters: ["guest"]
            ),
            QueueItem(
                id: "song-2",
                song: Song(
                    id: "song-2",
                    title: "Blinding Lights",
                    artist: "The Weeknd",
                    albumArtURL: nil,
                    duration: 200
                ),
                addedBy: Peer(name: "Sam"),
                voters: []
            )
        ],
        pendingVotes: ["song-2"],
        myPeerID: "guest",
        onVote: { _ in }
    )
}
