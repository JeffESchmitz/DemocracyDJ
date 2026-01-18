import Foundation
import Testing
@testable import Shared

@Test func peerEncodesAndDecodes() throws {
    let peer = Peer(id: "test-id", name: "Dad's iPhone")
    let data = try JSONEncoder().encode(peer)
    let decoded = try JSONDecoder().decode(Peer.self, from: data)

    #expect(decoded.id == peer.id)
    #expect(decoded.name == peer.name)
}

@Test func songEncodesAndDecodes() throws {
    let song = Song(
        id: "music-123",
        title: "Master of Puppets",
        artist: "Metallica",
        albumArtURL: URL(string: "https://example.com/art.jpg"),
        duration: 515
    )

    let data = try JSONEncoder().encode(song)
    let decoded = try JSONDecoder().decode(Song.self, from: data)

    #expect(decoded.id == song.id)
    #expect(decoded.title == song.title)
    #expect(decoded.artist == song.artist)
    #expect(decoded.duration == song.duration)
}

@Test func queueItemEncodesAndDecodes() throws {
    let peer = Peer(id: "peer-1", name: "Santiago")
    let song = Song(
        id: "music-123",
        title: "Master of Puppets",
        artist: "Metallica",
        albumArtURL: URL(string: "https://example.com/art.jpg"),
        duration: 515
    )
    let queueItem = QueueItem(
        id: song.id,
        song: song,
        addedBy: peer,
        voters: ["peer-1", "peer-2"]
    )

    let data = try JSONEncoder().encode(queueItem)
    let decoded = try JSONDecoder().decode(QueueItem.self, from: data)

    #expect(decoded.id == song.id)
    #expect(decoded.song.title == song.title)
    #expect(decoded.addedBy.id == peer.id)
    #expect(decoded.voteCount == 2)
}

@Test func meshMessageRoundTrips() throws {
    let peer = Peer(name: "Test")
    let song = Song(
        id: "1",
        title: "Test Song",
        artist: "Test Artist",
        albumArtURL: nil,
        duration: 180
    )
    let queueItem = QueueItem(
        id: song.id,
        song: song,
        addedBy: peer,
        voters: [peer.id]
    )

    // Test GuestIntent
    let intent = MeshMessage.intent(.suggestSong(song))
    let intentData = try JSONEncoder().encode(intent)
    let decodedIntent = try JSONDecoder().decode(MeshMessage.self, from: intentData)

    if case .intent(.suggestSong(let decodedSong)) = decodedIntent {
        #expect(decodedSong.title == "Test Song")
    } else {
        Issue.record("Expected .intent(.suggestSong)")
    }

    // Test HostSnapshot
    let snapshot = HostSnapshot(
        nowPlaying: song,
        queue: [queueItem],
        connectedPeers: [peer],
        isPlaying: true
    )
    let update = MeshMessage.stateUpdate(snapshot)
    let updateData = try JSONEncoder().encode(update)
    let decodedUpdate = try JSONDecoder().decode(MeshMessage.self, from: updateData)

    if case .stateUpdate(let decodedSnapshot) = decodedUpdate {
        #expect(decodedSnapshot.nowPlaying?.title == "Test Song")
        #expect(decodedSnapshot.queue.first?.voteCount == 1)
        #expect(decodedSnapshot.isPlaying == true)
    } else {
        Issue.record("Expected .stateUpdate")
    }
}
