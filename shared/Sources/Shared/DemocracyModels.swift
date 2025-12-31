import Foundation

// MARK: - The Atoms of Democracy

/// Represents a unique device in the mesh network.
/// We use a clean struct instead of MCPeerID to keep our logic pure.
public struct Peer: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: String   // UUID string or stable device ID
    public let name: String // "Santiago's iPhone"

    public init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
    }
}

/// A Song that can be voted on.
/// This mirrors the 'Song' type from your React prototype.
public struct Song: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: String       // Persistent Store ID (MusicKit ID)
    public let title: String
    public let artist: String
    public let albumArtURL: URL?
    public let duration: TimeInterval

    public init(
        id: String,
        title: String,
        artist: String,
        albumArtURL: URL?,
        duration: TimeInterval
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.albumArtURL = albumArtURL
        self.duration = duration
    }
}

/// The mutable queue state for a song in the session.
public struct QueueItem: Identifiable, Equatable, Codable, Sendable {
    public let id: String // Same as song.id for simplicity
    public let song: Song
    public let addedBy: Peer
    public var voters: Set<String> // Peer IDs who have voted

    public var voteCount: Int { voters.count }

    public init(id: String, song: Song, addedBy: Peer, voters: Set<String>) {
        self.id = id
        self.song = song
        self.addedBy = addedBy
        self.voters = voters
    }
}

// MARK: - The Wire Protocol

/// The top-level wrapper for all communication over the Mesh Network.
/// This ensures strict typing when decoding data streams.
public enum MeshMessage: Equatable, Codable, Sendable {
    /// Sent by Guest -> Host
    /// "I want to do something"
    case intent(GuestIntent)

    /// Sent by Host -> Guest
    /// "Here is the new truth"
    case stateUpdate(HostSnapshot)
}

/// Actions a Guest can take.
public enum GuestIntent: Equatable, Codable, Sendable {
    /// "I found this song on Apple Music, please add it."
    case suggestSong(Song)

    /// "I like this song (or dislike it)."
    case vote(songID: String)
}

/// The "Source of Truth" broadcasted by the Host.
public struct HostSnapshot: Equatable, Codable, Sendable {
    public let nowPlaying: Song?
    public let queue: [QueueItem] // Already sorted by votes
    public let connectedPeers: [Peer]

    public init(nowPlaying: Song?, queue: [QueueItem], connectedPeers: [Peer]) {
        self.nowPlaying = nowPlaying
        self.queue = queue
        self.connectedPeers = connectedPeers
    }
}
