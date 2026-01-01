# ADR 001: HostSnapshot Update Strategy

## Status
Accepted

## Context
When the host queue changes, the host must synchronize state to all guests. We considered two approaches:

1. Full snapshot: send the entire HostSnapshot on every change.
2. Incremental diffs: send only the changed fields or events.

## Decision
Broadcast a full HostSnapshot on every mutation.

## Rationale
- Local mesh bandwidth is sufficient for small JSON payloads (~1 KB).
- Simplicity beats efficiency in V1.
- Full snapshots prevent state drift bugs between host and guests.
- Expected peer count is small (< 6).

## Consequences
- Slightly more bandwidth usage (acceptable for V1).
- No diffing or patch logic to maintain.
- Guests can always treat snapshots as the complete source of truth.
