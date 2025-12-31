# iOS CLAUDE.md

This file provides iOS-specific guidance for Claude Code. See the root `../CLAUDE.md` and `../docs/CLAUDE_PLAN.md` for project-wide architecture.

## TCA Conventions

### Feature Folder Structure
```
Features/
├── App/
│   ├── AppFeature.swift      # Root reducer
│   └── AppView.swift         # Root view
├── Host/
│   ├── HostFeature.swift     # Driver's reducer
│   └── HostView.swift        # Driver's UI
└── Guest/
    ├── GuestFeature.swift    # Passenger's reducer
    └── GuestView.swift       # Passenger's UI
```

### Naming Conventions
- Reducers: `*Feature` (e.g., `HostFeature`)
- Views: `*View` (e.g., `HostView`)
- Dependencies: `*Client` (e.g., `MultipeerClient`, `MusicKitClient`)

### Reducer Pattern
```swift
@Reducer
struct HostFeature {
    @ObservableState
    struct State: Equatable { ... }

    enum Action { ... }

    @Dependency(\.multipeerClient) var multipeerClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            // Logic here
        }
    }
}
```

### View Pattern
```swift
struct HostView: View {
    @Bindable var store: StoreOf<HostFeature>

    var body: some View {
        // UI here
    }
}

#Preview {
    HostView(store: Store(initialState: .init()) {
        HostFeature()
    })
}
```

## Architecture Rules (CRITICAL)

1. **MCPeerID Boundary**: `MCPeerID` never escapes `MultipeerClient`—use `Peer` struct
2. **MusicKit Host-Only**: Only `HostFeature` gets `MusicKitClient`—never `GuestFeature`
3. **Host is Source of Truth**: `HostSnapshot` replaces guest state entirely
4. **Idempotent Voting**: `QueueItem.voters` is `Set<String>`—duplicates are no-ops
5. **Full Snapshots**: Broadcast entire `HostSnapshot` on every change

## Dependencies Location

```
Dependencies/
├── MultipeerClient.swift     # Mesh networking abstraction
└── MusicKitClient.swift      # Audio playback (future)
```

## Testing

### Reducer Tests
```swift
@Test func votingIsIdempotent() async {
    let store = TestStore(initialState: HostFeature.State(...)) {
        HostFeature()
    }

    await store.send(.processIntent(.vote(songID: "1"), from: peer)) {
        $0.queue[0].voters.insert(peer.id)
    }

    // Second vote from same peer is no-op
    await store.send(.processIntent(.vote(songID: "1"), from: peer))
}
```

### Testing with MultipeerClient

#### Unit Test Pattern
```swift
@Test func hostReceivesVote() async {
    // Create mock event stream with continuation for control
    let (stream, continuation) = AsyncStream.makeStream(of: MultipeerEvent.self)

    let store = TestStore(initialState: HostFeature.State()) {
        HostFeature()
    } withDependencies: {
        $0.multipeerClient = .mock(events: stream)
    }

    // Simulate peer connection
    continuation.yield(.peerConnected(Peer(id: "test", name: "Test")))

    // Test reducer behavior...
}
```

#### Intercepting Method Calls
```swift
@Test func hostStartsAdvertising() async {
    var didStartHosting = false
    var hostDisplayName: String?

    let store = TestStore(initialState: HostFeature.State()) {
        HostFeature()
    } withDependencies: {
        $0.multipeerClient = .mock(
            onStartHosting: { name in
                didStartHosting = true
                hostDisplayName = name
            }
        )
    }

    await store.send(.startHosting("My Party"))
    #expect(didStartHosting)
    #expect(hostDisplayName == "My Party")
}
```

### Preview Dependencies
Use `.previewValue` for SwiftUI previews with mock data. The preview mock automatically emits 3 connected peers.

#### Preview Pattern
```swift
#Preview {
    HostView(store: Store(initialState: .init()) {
        HostFeature()
    })
    // Uses .previewValue automatically - 3 peers connect on appear
}
```

## Build Commands

```bash
# Open in Xcode
open DemocracyDJ.xcodeproj

# Build via CLI (requires Xcode 26+)
xcodebuild -scheme DemocracyDJ -sdk iphonesimulator build
```
