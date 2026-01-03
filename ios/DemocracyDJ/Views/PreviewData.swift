import Foundation
import Shared

extension SubscriptionStatus {
    static let subscribed = SubscriptionStatus(
        canPlayCatalogContent: true,
        canBecomeSubscriber: false
    )

    static let notSubscribed = SubscriptionStatus(
        canPlayCatalogContent: false,
        canBecomeSubscriber: true
    )

    static let cannotSubscribe = SubscriptionStatus(
        canPlayCatalogContent: false,
        canBecomeSubscriber: false
    )
}

extension Song {
    static let previewSong = Song(
        id: "song-1",
        title: "Bohemian Rhapsody",
        artist: "Queen",
        albumArtURL: URL(string: "https://picsum.photos/300"),
        duration: 354
    )

    static let previewSong2 = Song(
        id: "song-2",
        title: "Hotel California",
        artist: "Eagles",
        albumArtURL: nil,
        duration: 391
    )

    static let previewSong3 = Song(
        id: "song-3",
        title: "Levitating",
        artist: "Dua Lipa",
        albumArtURL: URL(string: "https://picsum.photos/301"),
        duration: 203
    )
}

extension Array where Element == QueueItem {
    static let previewQueue: [QueueItem] = [
        QueueItem(
            id: Song.previewSong2.id,
            song: Song.previewSong2,
            addedBy: Peer(name: "Dad"),
            voters: [UUID().uuidString, UUID().uuidString]
        ),
        QueueItem(
            id: Song.previewSong3.id,
            song: Song.previewSong3,
            addedBy: Peer(name: "Teenager"),
            voters: [UUID().uuidString]
        )
    ]
}
