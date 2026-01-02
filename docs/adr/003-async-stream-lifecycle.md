# ADR 003: AsyncStream Lifecycle Rules

## Context
`MultipeerClient` exposes an `AsyncStream` of events. Without clear lifecycle rules, multiple subscribers can split events, continuations can dangle after cancellation, and streams can leak after `stop()`.

## Decision
We adopt a single-subscriber model with explicit lifecycle rules:

- Each `MultipeerClient` instance supports exactly one active subscriber.
- `events()` returns the same stream instance for the lifetime of the client.
- The stream is created lazily on first call to `events()`.
- `stop()` finishes the stream and clears the continuation.
- Cancellation of the consumer loop triggers termination and clears the stream instance.
- Cancellation does not stop networking; only `stop()` shuts down MultipeerConnectivity.

## Consequences
Features must cancel event loops when stopping (use TCA `.cancellable`).
Multiple consumers must be coordinated by a parent reducer rather than calling `events()` independently.
Ownership of stream lifecycle is explicit and prevents leaks or split delivery.
