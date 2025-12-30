# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Canonical Authority

**`docs/CLAUDE_PLAN.md` is the single source of truth.** If there is any conflict between this file, GitHub Issues, or scripts, that document wins. Read it before writing any code.

## Build & Test Commands

### Web (React Prototype)
```bash
cd web && npm install           # Install dependencies
cd web && npm run dev           # Start Vite dev server
cd web && npm run build         # Type-check + production build
cd web && npm run lint          # Run ESLint
cd web && npm run preview       # Serve production build locally
```

### Shared Swift Package
```bash
swift test --package-path shared  # Run all Swift tests
```

### iOS
```bash
open ios/DemocracyDJ.xcodeproj   # Open in Xcode
```

## Architecture

**Democracy DJ** is a road trip jukebox that prioritizes songs by vote count using local mesh networking.

### Monorepo Structure
- `ios/` - Native iOS app (SwiftUI + TCA, iOS 17+)
- `web/` - React prototype for rapid UI/voting logic validation
- `shared/` - Swift Package with domain models shared across platforms
- `docs/` - Architecture docs, design exports

### Key Roles
- **Host (Driver)**: Controls playback, owns the source-of-truth queue, broadcasts state
- **Guests (Passengers)**: Join via MultipeerConnectivity, vote on songs, receive state updates

### Core Domain Models (in `shared/Sources/Shared/`)
- `Peer` - Device identity (id + display name)
- `Song` - Immutable music metadata
- `QueueItem` - Song in queue with voters set and computed vote count
- `HostSnapshot` - Broadcast state: nowPlaying, queue, connectedPeers
- `MeshMessage` - Wire protocol (GuestIntent or HostSnapshot)
- `GuestIntent` - Actions guests can take (suggestSong, vote)

### TCA Feature Structure
- `AppFeature` - Root, owns mode selection, composes Host/Guest
- `HostFeature` - Owns queue state, broadcasts snapshots, has MusicKitClient
- `GuestFeature` - Receives snapshots, sends intents, NO MusicKitClient access

## Inviolable Architecture Rules

1. **MCPeerID Boundary**: `MCPeerID` never escapes `MultipeerClient`—domain code uses `Peer` struct
2. **MusicKit Host-Only**: Only injected into HostFeature, never GuestFeature
3. **Host is Source of Truth**: `HostSnapshot` replaces guest local state entirely
4. **Idempotent Voting**: `QueueItem.voters` is `Set<String>`—duplicate votes are no-ops
5. **Full Snapshots**: Broadcast entire `HostSnapshot` on every change (no diffing)

## Coding Conventions

### TypeScript/React (Web)
- 2-space indentation, semicolons, single quotes
- PascalCase components, `use*` hooks
- Follow patterns in `web/src/App.tsx`

### Swift
- Standard Swift conventions
- Keep shared model names aligned with web prototypes
- TCA patterns for iOS features
- Swift 6 strict concurrency

### Git
- **NEVER commit to `main` directly** — always create a branch first
- Before ANY code change: `git branch --show-current` → if on `main`, create branch immediately
- Branch pattern: `tm/jeffrey.schmitz2/jdi/{descriptive-name}`
- Conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`

## Development Phases

1. **Web PoC (Current)**: Validate voting logic/UI in React
2. **Native Port**: Migrate to TCA reducers + MultipeerConnectivity

## Testing Requirements

- All reducers must have `TestStore` tests
- All views must work in SwiftUI Previews with mock dependencies
- Swift tests in `shared/Tests/SharedTests/`
- Mesh testing requires two physical iOS devices
