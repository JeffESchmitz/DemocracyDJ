#!/bin/bash

# ============================================================================
# DemocracyDJ Issue Setup Script
# ============================================================================
# Run this ONCE from the root of your git repository.
# Requires: GitHub CLI (gh) installed and authenticated.
#
# NOTE FOR AI AGENTS (Claude Code):
# This script is a ONE-TIME project hydration tool.
# It creates GitHub labels, milestones, and issues.
#
# This script does NOT define architecture, behavior, or scope.
# The canonical execution guide is:
#   - docs/CLAUDE_PLAN.md
#
# If there is any conflict between this script, GitHub issues,
# or comments, docs/CLAUDE_PLAN.md takes precedence.
#
# DO NOT modify, regenerate, or re-run this script during implementation.
# ============================================================================

set -e  # Exit on error

echo "🚀 Initializing DemocracyDJ Project Management..."
echo ""

# ============================================================================
# 1. CREATE LABELS
# ============================================================================
echo "🏷️  Creating Labels..."

gh label create "setup" --color "D4C5F9" --description "Project configuration and scaffolding" --force
gh label create "architecture" --color "0E8A16" --description "Design decisions and interfaces" --force
gh label create "feature" --color "A2EEEF" --description "TCA reducer implementation" --force
gh label create "ui" --color "D93F0B" --description "SwiftUI views" --force
gh label create "networking" --color "1D76DB" --description "MultipeerConnectivity work" --force
gh label create "testing" --color "C2E0C6" --description "Test coverage" --force
gh label create "documentation" --color "0075CA" --description "CLAUDE.md, README, etc." --force
gh label create "dx" --color "E99695" --description "Developer experience improvements" --force
gh label create "future" --color "6F5886" --description "Backlog items for later" --force
gh label create "tca" --color "FEF2C0" --description "Composable Architecture specific" --force
gh label create "ios" --color "000000" --description "iOS platform specific" --force
gh label create "swiftui" --color "F05138" --description "SwiftUI specific" --force

echo "✅ Labels created"
echo ""

# ============================================================================
# 2. CREATE MILESTONES
# ============================================================================
echo "🚩 Creating Milestones..."

gh milestone create --title "Milestone 1: Walking Skeleton" --description "App compiles, runs, and navigates between modes with mocks." 2>/dev/null || echo "   (Milestone 1 already exists)"
gh milestone create --title "Milestone 2: Multipeer Networking" --description "Real device-to-device communication implemented." 2>/dev/null || echo "   (Milestone 2 already exists)"
gh milestone create --title "Milestone 3: Host Flow" --description "Driver can manage queue and broadcast state." 2>/dev/null || echo "   (Milestone 3 already exists)"
gh milestone create --title "Milestone 4: Guest Flow" --description "Passengers can join and vote." 2>/dev/null || echo "   (Milestone 4 already exists)"
gh milestone create --title "Milestone 5: MusicKit (Future)" --description "Actual audio playback integration." 2>/dev/null || echo "   (Milestone 5 already exists)"

echo "✅ Milestones created"
echo ""

# ============================================================================
# 3. CREATE ISSUES
# ============================================================================

# --- Epic 1: Foundation ---
echo "📝 Creating Epic 1: Foundation Issues..."

gh issue create --title "Scaffold iOS Xcode Project with TCA" \
  --label "setup,ios" \
  --milestone "Milestone 1: Walking Skeleton" \
  --body "$(cat <<'EOF'
Create the iOS app target in the `/ios` directory with proper TCA integration and link to the existing Shared Swift package.

## Acceptance Criteria
- [ ] Xcode project at `ios/DemocracyDJ.xcodeproj`
- [ ] Minimum deployment target iOS 17
- [ ] Swift 6 language mode with strict concurrency checking enabled
- [ ] Dependencies added via SPM: `swift-composable-architecture` (latest 1.x)
- [ ] Local `Shared` package linked from `../shared`
- [ ] App builds and runs with a placeholder "Hello Democracy" view

## Project Structure
```
ios/
├── DemocracyDJ.xcodeproj
├── DemocracyDJ/
│   ├── App/
│   │   └── DemocracyDJApp.swift
│   ├── Features/
│   │   ├── App/
│   │   ├── Host/
│   │   └── Guest/
│   ├── Dependencies/
│   └── Resources/
└── DemocracyDJTests/
```

## Non-Goals
- No feature implementation yet
- No real UI beyond placeholder
EOF
)"

gh issue create --title "Create CLAUDE.md for iOS directory" \
  --label "documentation,dx" \
  --milestone "Milestone 1: Walking Skeleton" \
  --body "$(cat <<'EOF'
Add a `CLAUDE.md` file to guide Claude Code through the project conventions, architecture decisions, and coding standards.

## Required Sections

### Project Overview
- Democracy DJ: Road trip jukebox with mesh networking
- Host (driver) controls playback, Guests (passengers) vote

### TCA Conventions
- Feature folder structure: `Feature.swift`, `FeatureView.swift`
- Naming: `*Feature` for reducers, `*View` for SwiftUI views
- Dependency injection via `@Dependency`

### Architecture Rules (CRITICAL)
1. `MCPeerID` NEVER escapes `MultipeerClient` — all domain code uses `Peer`
2. `MusicKitClient` is ONLY injected into `HostFeature` — NEVER into `GuestFeature`
3. `HostSnapshot` is the source of truth — Guests never mutate queue locally
4. Votes are idempotent — one vote per peer per song (enforced via `QueueItem.voters`)
5. Full snapshots, not diffs — broadcast entire state on every change

### Testing Expectations
- Reducers must have unit tests using `TestStore`
- Use mock dependencies for previews and tests

### Git Conventions
- Branch pattern: `tm/jeffrey.schmitz2/jdi/{name}`
- No AI attribution in commits or PRs

### Authority Hierarchy
- `docs/CLAUDE_PLAN.md` is the canonical source of truth
- GitHub Issues define task boundaries
- When in conflict, CLAUDE_PLAN.md wins

## Acceptance Criteria
- [ ] `ios/CLAUDE.md` exists with all sections above
- [ ] Claude Code can read and follow conventions
EOF
)"

gh issue create --title "Refactor Shared Models to use QueueItem" \
  --label "architecture,setup" \
  --milestone "Milestone 1: Walking Skeleton" \
  --body "$(cat <<'EOF'
Refactor the Shared models to separate immutable `Song` data from mutable queue state. This prevents vote spamming and enables idempotent voting.

## Current Problem
`Song` has `voteCount` but doesn't track WHO voted, allowing spam.

## Required Changes

### New QueueItem Model
```swift
public struct QueueItem: Identifiable, Equatable, Codable, Sendable {
    public let id: String  // Same as song.id for simplicity
    public let song: Song
    public let addedBy: Peer
    public var voters: Set<String>  // Peer IDs who have voted
    
    public var voteCount: Int { voters.count }
}
```

### Update Song (remove vote data)
```swift
public struct Song: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let albumArtURL: URL?
    public let duration: TimeInterval
    // REMOVED: addedBy, voteCount
}
```

### Update HostSnapshot
```swift
public struct HostSnapshot: Codable, Sendable {
    public let nowPlaying: Song?
    public let queue: [QueueItem]  // Changed from [Song]
    public let connectedPeers: [Peer]
}
```

### Update GuestIntent
```swift
public enum GuestIntent: Codable, Sendable {
    case suggestSong(Song)
    case vote(songID: String)  // Remove VoteDirection — upvote only
}
```

### Remove VoteDirection
Delete the `VoteDirection` enum entirely. Positive vibes only.

## Non-Goals
- No networking code
- No reducer logic
- No UI

## Acceptance Criteria
- [ ] `QueueItem` model exists with `voters: Set<String>`
- [ ] `Song` no longer has `voteCount` or `addedBy`
- [ ] `HostSnapshot.queue` is `[QueueItem]`
- [ ] `VoteDirection` enum removed
- [ ] All existing tests updated and passing
- [ ] JSONEncoder/Decoder round-trip works
EOF
)"

gh issue create --title "ADR: HostSnapshot Update Strategy" \
  --label "architecture,documentation" \
  --milestone "Milestone 1: Walking Skeleton" \
  --body "$(cat <<'EOF'
Document the Architectural Decision Record (ADR) for how state is broadcast to peers.

## Context
When the Host's queue changes, we need to sync state to all Guests. Two options:
1. **Full Snapshot** — Send entire `HostSnapshot` on every change
2. **Incremental Diffs** — Send only what changed

## Decision
**Full Snapshot Broadcasts** on every mutation.

## Rationale
- Local mesh network bandwidth is sufficient for small JSON payloads (~1KB)
- Simplicity > efficiency for v1
- Prevents "state drift" bugs between host and guests
- Expected peer count < 6

## Consequences
- Slightly more bandwidth usage (acceptable)
- No complex diffing/patching logic to maintain
- Guests can always trust snapshot is complete

## Deliverable
Create `docs/adr/001-snapshot-strategy.md` with the above content in proper ADR format.

## Acceptance Criteria
- [ ] ADR document exists in `docs/adr/`
- [ ] Decision is clear and justified
- [ ] Team understands we are NOT optimizing bandwidth yet
EOF
)"

# --- Epic 2: Multipeer Dependency ---
echo "📝 Creating Epic 2: Multipeer Networking Issues..."

gh issue create --title "Design MultipeerClient Dependency Interface" \
  --label "architecture,networking" \
  --milestone "Milestone 1: Walking Skeleton" \
  --body "$(cat <<'EOF'
Define the TCA dependency interface for MultipeerConnectivity. This is the CONTRACT only—implementation comes in a separate issue.

## Interface Definition

```swift
// MARK: - Client

struct MultipeerClient: Sendable {
    var startHosting: @Sendable (_ displayName: String) async -> Void
    var startBrowsing: @Sendable (_ displayName: String) async -> Void
    var stop: @Sendable () async -> Void
    var send: @Sendable (_ message: MeshMessage, _ to: Peer?) async throws -> Void
    var events: @Sendable () -> AsyncStream<MultipeerEvent>
}

// MARK: - Events

enum MultipeerEvent: Sendable, Equatable {
    case peerDiscovered(Peer)
    case peerConnected(Peer)
    case peerDisconnected(Peer)
    case messageReceived(MeshMessage, from: Peer)
}

// MARK: - Dependency Key

extension MultipeerClient: DependencyKey {
    static let liveValue: MultipeerClient = .live  // Stub for now
    static let testValue: MultipeerClient = .mock
    static let previewValue: MultipeerClient = .preview
}

extension DependencyValues {
    var multipeerClient: MultipeerClient {
        get { self[MultipeerClient.self] }
        set { self[MultipeerClient.self] = newValue }
    }
}
```

## File Location
`ios/DemocracyDJ/Dependencies/MultipeerClient.swift`

## Non-Goals
- No actual MultipeerConnectivity code yet
- No MCSession, MCPeerID, etc.
- No UI
- No reducers

## Acceptance Criteria
- [ ] `MultipeerClient` struct defined with all methods
- [ ] `MultipeerEvent` enum defined with all cases
- [ ] `DependencyKey` conformance compiles
- [ ] `.testValue` returns a no-op mock
- [ ] Interface uses ONLY `Shared` types (`Peer`, `MeshMessage`)
- [ ] `MCPeerID` does not appear anywhere in this file
EOF
)"

gh issue create --title "Implement MultipeerClient Live Dependency" \
  --label "networking,ios" \
  --milestone "Milestone 2: Multipeer Networking" \
  --body "$(cat <<'EOF'
Implement the actual MultipeerConnectivity logic wrapped in an Actor for thread safety.

## Architecture

### Internal Actor
```swift
actor MultipeerActor {
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var peerMap: [MCPeerID: Peer] = [:]  // MCPeerID NEVER escapes this actor
    
    private var eventContinuation: AsyncStream<MultipeerEvent>.Continuation?
}
```

### Responsibilities
- Own `MCSession`, `MCNearbyServiceAdvertiser`, `MCNearbyServiceBrowser`
- Sanitize `MCPeerID` → `Peer` at the boundary (peerMap)
- Encode/decode `MeshMessage` via `JSONEncoder`/`JSONDecoder`
- Emit events via `AsyncStream` continuation
- Handle all `MCSessionDelegate` callbacks

### Service Configuration
- Service type: `"democracy-dj"` (≤15 chars, lowercase + hyphen)
- Discovery info: `["version": "1"]`

### Thread Safety
- All MC delegate callbacks must dispatch to actor context
- Use `@preconcurrency import MultipeerConnectivity` if needed for Swift 6

## Non-Goals
- No fallback to Internet/WebSockets (mesh only for v1)
- No Android or Web peer support
- No UI
- No business logic

## Acceptance Criteria
- [ ] `MultipeerClient.liveValue` uses real MultipeerConnectivity
- [ ] `MCPeerID` NEVER escapes `MultipeerActor`
- [ ] Can advertise (host) and browse (guest) correctly
- [ ] Messages encode/decode via JSON
- [ ] Events stream to reducers correctly
- [ ] Works on iOS 17+ with strict concurrency
- [ ] Tested on 2 physical devices
EOF
)"

gh issue create --title "Create Mock MultipeerClient for Testing & Previews" \
  --label "testing,dx" \
  --milestone "Milestone 1: Walking Skeleton" \
  --body "$(cat <<'EOF'
Create mock and preview implementations of `MultipeerClient` for unit tests and SwiftUI previews.

## Test Mock
```swift
extension MultipeerClient {
    static func mock(
        events: AsyncStream<MultipeerEvent> = AsyncStream { $0.finish() }
    ) -> Self {
        MultipeerClient(
            startHosting: { _ in },
            startBrowsing: { _ in },
            stop: { },
            send: { _, _ in },
            events: { events }
        )
    }
}
```

## Preview Mock
```swift
extension MultipeerClient {
    static var preview: Self {
        // Returns a client that simulates:
        // - 3 connected peers: Diego, Eduardo, Santiago
        // - Periodic fake vote events (optional)
    }
}
```

## Usage in Tests
```swift
let store = TestStore(initialState: HostFeature.State()) {
    HostFeature()
} withDependencies: {
    $0.multipeerClient = .mock(events: mockEventStream)
}
```

## Non-Goals
- No real networking
- No device testing

## Acceptance Criteria
- [ ] `.testValue` is controllable via parameters
- [ ] `.previewValue` simulates 3 realistic peers
- [ ] SwiftUI previews work without physical devices
- [ ] Unit tests can inject specific event sequences
- [ ] Usage documented in `ios/CLAUDE.md`
EOF
)"

# --- Epic 3: Host Feature ---
echo "📝 Creating Epic 3: Host Feature Issues..."

gh issue create --title "Implement HostFeature Reducer" \
  --label "feature,tca" \
  --milestone "Milestone 3: Host Flow" \
  --body "$(cat <<'EOF'
Create the TCA reducer that manages the Host (driver) state—the source of truth for the music queue.

## State
```swift
@Reducer
struct HostFeature {
    @ObservableState
    struct State: Equatable {
        var nowPlaying: Song?
        var queue: [QueueItem] = []
        var connectedPeers: [Peer] = []
        var isHosting: Bool = false
        var myPeer: Peer
    }
}
```

## Actions
```swift
enum Action {
    // Lifecycle
    case startHosting
    case stopHosting
    
    // Playback
    case playTapped
    case pauseTapped
    case skipTapped
    
    // Network
    case multipeerEvent(MultipeerEvent)
    
    // Internal
    case _processIntent(GuestIntent, from: Peer)
    case _broadcastSnapshot
}
```

## Logic Rules

### Voting (CRITICAL)
- Votes are **idempotent per Peer**
- When processing `.vote(songID:)`:
  1. Find `QueueItem` by songID
  2. Insert peer ID into `voters` set
  3. If already present → no-op (Set handles this)
- `voteCount` is computed: `voters.count`

### Queue Sorting
- Primary sort: `voteCount` descending
- Tie-breaker: earlier insertion wins (stable sort)

### Skip Logic
- `skipTapped`: promote `queue[0]` to `nowPlaying`, remove from queue
- If queue empty after skip: `nowPlaying` = nil

### Broadcasting
- After ANY state mutation that affects queue/nowPlaying:
  - Build `HostSnapshot` from current state
  - Send to all peers via `multipeerClient.send`
- Use `Effect.send(._broadcastSnapshot)` pattern

## Non-Goals
- No MusicKit playback (mock for now)
- No persistence
- No UI

## Acceptance Criteria
- [ ] `HostFeature.swift` in `ios/DemocracyDJ/Features/Host/`
- [ ] Voting is idempotent (test: same peer votes twice = 1 vote)
- [ ] Queue sorts correctly by votes, then by insertion order
- [ ] `skipTapped` promotes correctly
- [ ] Snapshot broadcasts on every relevant mutation
- [ ] Subscribes to `multipeerClient.events` on `startHosting`
- [ ] Unit tests cover ALL logic rules above
EOF
)"

gh issue create --title "Create HostView UI" \
  --label "ui,swiftui" \
  --milestone "Milestone 3: Host Flow" \
  --body "$(cat <<'EOF'
Build the SwiftUI view for the Host/Driver screen, optimized for glanceability while driving.

## Layout

### Top Section: Now Playing (≈60% of screen)
- Large album art placeholder (colored rectangle, MusicKit artwork later)
- Song title (large, bold, ≥24pt)
- Artist name (medium, muted)
- Play/Pause button (≥60pt tap target)
- Skip button (≥44pt tap target)

### Bottom Section: Up Next (≈40% of screen)
- "Up Next" header
- Scrollable list of `QueueItem`s
- Each row shows:
  - Position number (1, 2, 3...)
  - Song title
  - Vote count badge
  - "Added by [Peer.name]"

### Status Badge
- "HOST" indicator (top corner)
- Connected peer count

## Requirements
- **Large tap targets** (driving safety)
- **Minimal cognitive load** (glanceable)
- Works in SwiftUI previews with mock store

## Non-Goals
- No animations
- No search UI
- No queue reordering (votes determine order)
- No MusicKit artwork yet

## Acceptance Criteria
- [ ] `HostView.swift` in `ios/DemocracyDJ/Features/Host/`
- [ ] Uses `@Bindable var store: StoreOf<HostFeature>`
- [ ] All buttons wire to correct actions
- [ ] Preview works with mock data
- [ ] Accessibility labels on all interactive elements
EOF
)"

# --- Epic 4: Guest Feature ---
echo "📝 Creating Epic 4: Guest Feature Issues..."

gh issue create --title "Implement GuestFeature Reducer" \
  --label "feature,tca" \
  --milestone "Milestone 4: Guest Flow" \
  --body "$(cat <<'EOF'
Create the TCA reducer for Guest (passenger) devices that receive state and send intents.

## State
```swift
@Reducer
struct GuestFeature {
    @ObservableState
    struct State: Equatable {
        var myPeer: Peer
        var connectionStatus: ConnectionStatus = .disconnected
        var hostSnapshot: HostSnapshot?
        var pendingVotes: Set<String> = []  // Song IDs with optimistic votes
        
        enum ConnectionStatus: Equatable {
            case disconnected
            case browsing
            case connecting(host: Peer)
            case connected(host: Peer)
        }
    }
}
```

## Actions
```swift
enum Action {
    // Lifecycle
    case startBrowsing
    case stopBrowsing
    case connectToHost(Peer)
    
    // User Actions
    case voteTapped(songID: String)
    case suggestSongTapped(Song)
    
    // Network
    case multipeerEvent(MultipeerEvent)
    
    // Internal
    case _snapshotReceived(HostSnapshot)
}
```

## Logic Rules

### Optimistic UI
- When `voteTapped`:
  1. Immediately add songID to `pendingVotes`
  2. Send `.intent(.vote(songID:))` via MultipeerClient
- When `_snapshotReceived`:
  1. Replace `hostSnapshot` entirely
  2. Clear `pendingVotes` (host confirmed state)

### Conflict Resolution
- `HostSnapshot` is ALWAYS the source of truth
- Guest NEVER mutates queue locally
- If snapshot differs from optimistic state, snapshot wins

### Intent Sending
- `voteTapped` → send `MeshMessage.intent(.vote(songID:))`
- `suggestSongTapped` → send `MeshMessage.intent(.suggestSong(_))`

## Non-Goals
- No playback controls (Guest is remote only)
- No queue authority
- No MusicKit access

## Acceptance Criteria
- [ ] `GuestFeature.swift` in `ios/DemocracyDJ/Features/Guest/`
- [ ] Guest cannot mutate queue locally
- [ ] Optimistic votes tracked in `pendingVotes`
- [ ] Snapshot received clears pending state
- [ ] Intents sent correctly via MultipeerClient
- [ ] Unit tests for all logic
EOF
)"

gh issue create --title "Create GuestView UI" \
  --label "ui,swiftui" \
  --milestone "Milestone 4: Guest Flow" \
  --body "$(cat <<'EOF'
Build the SwiftUI view for passengers to vote and suggest songs.

## Layout

### Top: Connection Status
- Status indicator (disconnected/browsing/connected)
- Host name when connected

### Header: Now Playing
- Shows `hostSnapshot?.nowPlaying`
- Non-interactive (passengers can't control playback)
- Album art placeholder + title + artist

### Main: Vote Queue
- List of `QueueItem`s from `hostSnapshot?.queue`
- Each row shows:
  - Album art placeholder
  - Song title + artist
  - Vote count badge (shows `queueItem.voteCount`)
  - "Added by [addedBy.name]"
  - Upvote button (heart or thumbs-up)
- Pending votes show visual indicator (dimmed/spinner)

### Bottom: Add Song
- "Add from Library" header
- Placeholder list (MusicKit search comes later)

## Requirements
- Immediate visual feedback on vote tap
- Disabled/empty state when `hostSnapshot` is nil
- Works in SwiftUI previews with mock snapshot

## Non-Goals
- No playback controls
- No MusicKit search yet
- No pull-to-refresh

## Acceptance Criteria
- [ ] `GuestView.swift` in `ios/DemocracyDJ/Features/Guest/`
- [ ] Binds to `QueueItem` properties (voteCount, addedBy)
- [ ] Vote button triggers `voteTapped` action
- [ ] Pending votes visually distinguished
- [ ] Disabled UI when not connected
- [ ] Preview works with mock `HostSnapshot`
EOF
)"

# --- Epic 5: App Shell ---
echo "📝 Creating Epic 5: App Shell Issues..."

gh issue create --title "Implement AppFeature Root Reducer" \
  --label "feature,tca" \
  --milestone "Milestone 1: Walking Skeleton" \
  --body "$(cat <<'EOF'
Create the root reducer that manages app-level state and mode switching.

## State
```swift
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var mode: Mode = .modeSelection
        var displayName: String = ""  // User's name for the mesh
        
        enum Mode: Equatable {
            case modeSelection
            case host(HostFeature.State)
            case guest(GuestFeature.State)
        }
    }
}
```

## Actions
```swift
enum Action {
    case displayNameChanged(String)
    case hostSelected
    case guestSelected
    case exitSession
    
    case host(HostFeature.Action)
    case guest(GuestFeature.Action)
}
```

## Composition
- Use `Scope` or `.ifCaseLet` to compose child features
- `hostSelected`:
  1. Create `Peer` from `displayName`
  2. Transition to `.host(HostFeature.State(myPeer: peer))`
- `guestSelected`:
  1. Create `Peer` from `displayName`
  2. Transition to `.guest(GuestFeature.State(myPeer: peer))`
- `exitSession`:
  1. Stop networking via `multipeerClient.stop()`
  2. Return to `.modeSelection`

## Non-Goals
- No persistence of mode selection
- No onboarding flow

## Acceptance Criteria
- [ ] `AppFeature.swift` in `ios/DemocracyDJ/Features/App/`
- [ ] Composes `HostFeature` and `GuestFeature`
- [ ] Mode transitions work correctly
- [ ] Exit session cleans up networking
- [ ] Unit tests for mode transitions
EOF
)"

gh issue create --title "Create Mode Selection Screen" \
  --label "ui,swiftui" \
  --milestone "Milestone 1: Walking Skeleton" \
  --body "$(cat <<'EOF'
Build the initial screen where user chooses Host (driver) or Guest (passenger).

## Layout

### Header
- "Democracy DJ" title
- Tagline: "Your road trip, your votes"

### Name Input
- Text field for display name
- Placeholder: "Enter your name"
- Required before selecting mode

### Mode Buttons (large, centered)
- **"I'm Driving"** → Host mode
  - Icon: 🚗 or steering wheel
  - Subtitle: "Control the music"
- **"I'm a Passenger"** → Guest mode
  - Icon: 🙋 or hand
  - Subtitle: "Vote on songs"

## Requirements
- Simple, obvious choices
- Buttons disabled until name entered
- Works in preview

## Non-Goals
- No settings screen
- No user accounts
- No persistence

## Acceptance Criteria
- [ ] `ModeSelectionView.swift` exists
- [ ] Name text field binds to `displayName`
- [ ] Two clear buttons for Host/Guest
- [ ] Buttons disabled when name empty
- [ ] Tapping triggers `hostSelected`/`guestSelected`
- [ ] Preview works
EOF
)"

gh issue create --title "Wire Up App Entry Point" \
  --label "setup,ios" \
  --milestone "Milestone 1: Walking Skeleton" \
  --body "$(cat <<'EOF'
Connect the TCA store to the SwiftUI App lifecycle.

## DemocracyDJApp.swift
```swift
import SwiftUI
import ComposableArchitecture

@main
struct DemocracyDJApp: App {
    static let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }
    
    var body: some Scene {
        WindowGroup {
            AppView(store: Self.store)
        }
    }
}
```

## AppView.swift
```swift
struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>
    
    var body: some View {
        switch store.mode {
        case .modeSelection:
            ModeSelectionView(store: store)
        case .host:
            if let hostStore = store.scope(state: \.host, action: \.host) {
                HostView(store: hostStore)
            }
        case .guest:
            if let guestStore = store.scope(state: \.guest, action: \.guest) {
                GuestView(store: guestStore)
            }
        }
    }
}
```

## Non-Goals
- No deep linking
- No state restoration

## Acceptance Criteria
- [ ] App launches to mode selection screen
- [ ] Selecting Host shows HostView
- [ ] Selecting Guest shows GuestView
- [ ] Exit returns to mode selection
- [ ] No crashes, no purple runtime warnings
- [ ] Live dependencies injected for release builds
EOF
)"

# --- Epic 6: MusicKit (Future) ---
echo "📝 Creating Epic 6: MusicKit Issues..."

gh issue create --title "Design MusicKitClient Dependency Interface" \
  --label "architecture,future" \
  --milestone "Milestone 5: MusicKit (Future)" \
  --body "$(cat <<'EOF'
Define the dependency interface for Apple MusicKit to search and play songs.

## Interface
```swift
struct MusicKitClient: Sendable {
    var requestAuthorization: @Sendable () async -> MusicAuthorization.Status
    var search: @Sendable (_ query: String) async throws -> [Song]
    var play: @Sendable (_ song: Song) async throws -> Void
    var pause: @Sendable () async -> Void
    var skip: @Sendable () async -> Void
    var playbackStatus: @Sendable () -> AsyncStream<PlaybackStatus>
}

struct PlaybackStatus: Equatable, Sendable {
    var isPlaying: Bool
    var currentTime: TimeInterval
    var duration: TimeInterval
}
```

## Architecture Rule (CRITICAL)
> ⚠️ `MusicKitClient` is ONLY injected into `HostFeature`.
> `GuestFeature` must NEVER have access to playback controls.
> This prevents accidental audio playback on passenger devices.

## Boundary Mapping
- Map `MusicKit.Song` → `Shared.Song` at the dependency boundary
- Never expose MusicKit types to reducers

## Non-Goals
- No implementation yet (future milestone)
- No UI

## Acceptance Criteria
- [ ] Interface defined in `Dependencies/MusicKitClient.swift`
- [ ] `DependencyKey` conformance
- [ ] Maps MusicKit types → Shared `Song` model
- [ ] Architecture rule documented in `ios/CLAUDE.md`
- [ ] `.testValue` returns mock
EOF
)"

# ============================================================================
# DONE
# ============================================================================
echo ""
echo "============================================================================"
echo "✅ DemocracyDJ project management initialized!"
echo "============================================================================"
echo ""
echo "Created:"
echo "  - 12 Labels"
echo "  - 5 Milestones"
echo "  - 16 Issues"
echo ""
echo "Next steps:"
echo "  1. Review issues at: https://github.com/JeffESchmitz/DemocracyDJ/issues"
echo "  2. Read docs/CLAUDE_PLAN.md (the canonical source of truth)"
echo "  3. Start with Milestone 1: Walking Skeleton"
echo ""
echo "🎵 Let the democracy begin!"
