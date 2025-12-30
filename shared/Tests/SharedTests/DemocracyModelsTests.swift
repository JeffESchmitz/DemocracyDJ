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
    let peer = Peer(name: "Santiago")
    let song = Song(
        id: "music-123",
        title: "Master of Puppets",
        artist: "Metallica",
        albumArtURL: URL(string: "https://example.com/art.jpg"),
        duration: 515,
        addedBy: peer,
        voteCount: 5
    )

    let data = try JSONEncoder().encode(song)
    let decoded = try JSONDecoder().decode(Song.self, from: data)

    #expect(decoded.id == song.id)
    #expect(decoded.title == song.title)
    #expect(decoded.voteCount == 5)
}

@Test func meshMessageRoundTrips() throws {
    let peer = Peer(name: "Test")
    let song = Song(
        id: "1",
        title: "Test Song",
        artist: "Test Artist",
        albumArtURL: nil,
        duration: 180,
        addedBy: peer
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
    let snapshot = HostSnapshot(nowPlaying: song, queue: [], connectedPeers: [peer])
    let update = MeshMessage.stateUpdate(snapshot)
    let updateData = try JSONEncoder().encode(update)
    let decodedUpdate = try JSONDecoder().decode(MeshMessage.self, from: updateData)

    if case .stateUpdate(let decodedSnapshot) = decodedUpdate {
        #expect(decodedSnapshot.nowPlaying?.title == "Test Song")
    } else {
        Issue.record("Expected .stateUpdate")
    }
}

@Test func voteDirectionRawValues() {
    #expect(VoteDirection.up.rawValue == 1)
    #expect(VoteDirection.down.rawValue == -1)
}
