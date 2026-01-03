import Shared
import SwiftUI

struct GuestQueueItemRow: View {
    let item: QueueItem
    let position: Int
    let hasVoted: Bool
    let onVote: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text("\(position)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.song.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(item.song.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Added by \(item.addedBy.name)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button(action: onVote) {
                HStack(spacing: 6) {
                    Image(systemName: hasVoted ? "hand.thumbsup.fill" : "hand.thumbsup")
                    Text("\(item.voters.count)")
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(hasVoted ? Color.blue : Color.secondary.opacity(0.15))
                .foregroundStyle(hasVoted ? .white : .primary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(hasVoted)
            .accessibilityLabel(hasVoted ? "Voted" : "Upvote")
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    GuestQueueItemRow(
        item: QueueItem(
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
        position: 1,
        hasVoted: true,
        onVote: {}
    )
    .padding()
}
