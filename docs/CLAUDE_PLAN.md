# Democracy DJ — Canonical Execution Plan

> **Authority Level: 🟥 HIGHEST**
>
> This document is the single source of truth for the Democracy DJ project.
> If there is any conflict between this document, GitHub Issues, or scripts,
> **this document wins**.

---

## Project Overview

**Democracy DJ** is a road trip jukebox that solves audio disputes through voting.

- **Host (Driver)**: Controls playback, holds the source of truth queue
- **Guests (Passengers)**: Join via local mesh network, vote on songs
- **The Democracy**: Songs are prioritized by vote count

### The Family

| Name     | Role      | Device         |
|----------|-----------|----------------|
| Dad/Jeff | Driver    | Host (iPhone)  |
| Diego    | Passenger | Guest          |
| Eduardo  | Passenger | Guest          |
| Santiago | Passenger | Guest          |

---

## Technical Stack

| Layer        | Technology                          |
|--------------|-------------------------------------|
| iOS App      | Swift 6, SwiftUI, iOS 17+           |
| Architecture | The Composable Architecture (TCA)   |
| Networking   | MultipeerConnectivity (mesh, no internet) |
| Audio        | MusicKit (future milestone)         |
| Shared Types | Swift Package (`/shared`)           |

---

## Architecture Rules

These rules are **inviolable**. Claude Code must follow them exactly.

### Rule 1: MCPeerID Boundary

```
MCPeerID NEVER escapes MultipeerClient
```

All domain code uses the `Peer` struct from the Shared package.
The `MultipeerActor` maintains an internal `[MCPeerID: Peer]` map.
No reducer, view, or test should ever import `MultipeerConnectivity`.

### Rule 2: MusicKit Host-Only

```
MusicKitClient is ONLY injected into HostFeature
```

`GuestFeature` must **never** have access to `MusicKitClient`.
This prevents accidental audio playback on passenger devices.
Enforce via dependency injection—don't even import it in Guest files.

### Rule 3: Host is Source of Truth

```
HostSnapshot is the single source of truth
```

Guests receive state, they don't own it.
When a Guest receives a `HostSnapshot`, it **replaces** local state entirely.
Guests may have optimistic UI (`pendingVotes`), but snapshot always wins.

### Rule 4: Idempotent Voting

```
One vote per peer per song
```

`QueueItem.voters` is a `Set<String>` of Peer IDs.
Duplicate votes from the same peer are no-ops (Set handles this).
`voteCount` is computed: `voters.count`.

### Rule 5: Full Snapshots

```
Broadcast entire HostSnapshot on every change
```

No diffing. No patches. No incremental updates.
When queue changes, serialize and send the whole thing.
Simplicity > efficiency for v1.

---

## Domain Models

Located in `/shared/Sources/Shared/DemocracyModels.swift`

### Peer
```swift
public struct Peer: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: String   // UUID string
    public let name: String // "Santiago's iPhone"
}
```

### Song (Immutable Metadata)
```swift
public struct Song: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let albumArtURL: URL?
    public let duration: TimeInterval
}
```

### QueueItem (Mutable Queue State)
```swift
public struct QueueItem: Identifiable, Equatable, Codable, Sendable {
    public let id: String        // Same as song.id
    public let song: Song
    public let addedBy: Peer
    public var voters: Set<String>  // Peer IDs
    
    public var voteCount: Int { voters.count }
}
```

### HostSnapshot (Broadcast State)
```swift
public struct HostSnapshot: Codable, Sendable {
    public let nowPlaying: Song?
    public let queue: [QueueItem]
    public let connectedPeers: [Peer]
}
```

### MeshMessage (Wire Protocol)
```swift
public enum MeshMessage: Codable, Sendable {
    case intent(GuestIntent)      // Guest → Host
    case stateUpdate(HostSnapshot) // Host → Guest
}
```

### GuestIntent
```swift
public enum GuestIntent: Codable, Sendable {
    case suggestSong(Song)
    case vote(songID: String)  // Upvote only, no downvotes
}
```

---

## Feature Architecture

### AppFeature (Root)
- Owns mode selection state
- Composes HostFeature and GuestFeature
- Handles mode transitions and cleanup

### HostFeature
- Owns: `nowPlaying`, `queue`, `connectedPeers`
- Receives: `GuestIntent` via MultipeerClient
- Broadcasts: `HostSnapshot` on every mutation
- Injects: `MultipeerClient`, `MusicKitClient` (future)

### GuestFeature
- Owns: `hostSnapshot` (received), `pendingVotes` (optimistic)
- Sends: `GuestIntent` via MultipeerClient
- Receives: `HostSnapshot` via MultipeerClient
- Injects: `MultipeerClient` only (NO MusicKitClient)

---

## Execution Order

```
Milestone 1: Walking Skeleton
├── Scaffold Xcode project
├── Create CLAUDE.md
├── Refactor Shared models (QueueItem)
├── ADR: Snapshot strategy
├── Design MultipeerClient interface
├── Create mock MultipeerClient
├── Implement AppFeature
├── Create ModeSelectionView
└── Wire up app entry point

Milestone 2: Multipeer Networking
└── Implement MultipeerClient live

Milestone 3: Host Flow
├── Implement HostFeature reducer
└── Create HostView

Milestone 4: Guest Flow
├── Implement GuestFeature reducer
└── Create GuestView

Milestone 5: MusicKit (Future)
├── Design MusicKitClient interface
└── Implement MusicKitClient live
```

**Rule**: Complete Milestone 1 before touching Milestone 2.
The Walking Skeleton must compile and run with mocks first.

---

## Testing Strategy

### Unit Tests (Required)
- All reducers must have `TestStore` tests
- Test voting idempotency
- Test queue sorting
- Test snapshot broadcasting

### Preview Tests (Required)
- All views must work in SwiftUI Previews
- Use `.previewValue` dependencies
- Mock all network state

### Integration Tests (Milestone 2+)
- Two-device mesh communication
- Message round-trip verification
- Requires physical devices

---

## Git Conventions

### Branch Naming
```
tm/jeffrey.schmitz2/jdi/{feature-name}
```

### Commit Messages
- Use conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`
- Be descriptive but concise
- **No AI attribution** in commits or PRs

### PR Requirements
- Link to GitHub Issue
- All tests passing
- Preview screenshots for UI changes

---

## Project Setup Script

A helper script exists at `scripts/setup_issues.sh`.

**Purpose:**
- Create GitHub labels, milestones, and issues
- One-time project hydration

**Rules:**
- Run at most once
- Do not modify or regenerate during implementation
- Do not infer behavior or architecture from the script
- This document (`CLAUDE_PLAN.md`) takes precedence over the script

---

## Handoff Instructions for Claude Code

Before writing any code:

1. **Read this document** (`docs/CLAUDE_PLAN.md`) and follow it exactly
2. **Check GitHub Issues** for task boundaries and acceptance criteria
3. **Do not introduce new scope** unless an issue explicitly requests it
4. **Do not refactor architecture** unless an issue explicitly requests it
5. **Ask for clarification** if requirements are ambiguous

When implementing a feature:

1. Create a feature branch following naming convention
2. Implement the minimum required by the issue
3. Write unit tests for reducers
4. Ensure previews work for views
5. Submit PR linking to the issue

---

## Questions?

If something in this document conflicts with an Issue or seems wrong,
**this document is authoritative**. Flag the conflict but follow this plan.

---

*Last updated: December 2024*
*Status: Ready for execution*
