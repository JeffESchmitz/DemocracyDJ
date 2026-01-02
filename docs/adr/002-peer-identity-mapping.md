# ADR 002: Peer Identity Mapping

## Context
MultipeerConnectivity assigns ephemeral `MCPeerID` values that can change across reconnects.
The app needs a stable identity to associate votes, queue ownership, and snapshots across sessions.
Platform types must not leak outside the transport layer.

## Decision
We adopt a two-layer identity model:

- `MCPeerID` is transport-only and must never leave `MultipeerActor`.
- `Peer.id` is the stable, app-level identity used throughout domain logic.

Rules:

1. Each device generates a persistent UUID (storage mechanism TBD in implementation).
2. That UUID is exchanged during discovery and/or invitation.
3. The host owns the canonical mapping of `Peer.id` -> `MCPeerID`.
4. On reconnect:
   - Same `Peer.id` -> update mapping, preserve identity.
   - New `Peer.id` -> treat as a new peer.
5. Votes, queue ownership, and snapshots are keyed by `Peer.id`, never `MCPeerID`.

Message Contract:

- Guest intents must include sender identity (`Peer.id`).
- Host snapshots reference peers by `Peer.id`.

## Consequences
This prevents identity drift across reconnects and keeps the domain layer platform-agnostic.
The host becomes the source of truth for mapping, simplifying guest logic.
Implementation must include a persistent UUID and handshake exchange prior to relying on identity in the queue or votes.
