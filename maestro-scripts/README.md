# Maestro Smoke Tests (Host ↔ Peer)

Maestro provides lightweight, accessibility-driven UI automation. This suite covers a minimal happy-path to verify Host ↔ Peer sync.

## Install Maestro

If Maestro is not installed:

```bash
brew install maestro
```

## Setup Simulators

Build the app in Xcode (Debug, Simulator). Then run:

```bash
APP_PATH="/path/to/DemocracyDJ.app" ./maestro-scripts/setup.sh
```

Defaults:
- Host device: `iPhone 17 Pro Max`
- Peer device: `iPhone 17 Pro`
- Bundle ID: `com.jeffschmitz.DemocracyDJ`

Override if needed:

```bash
HOST_DEVICE_NAME="iPhone 17 Pro" \
PEER_DEVICE_NAME="iPhone 17" \
APP_PATH="/path/to/DemocracyDJ.app" \
./maestro-scripts/setup.sh
```

Note: On first run you may need to accept local network and Apple Music permission dialogs manually.

If you want to see a minimal example, there is a simple `flow.yml` in the repo root you can run with:

```bash
maestro test flow.yml
```

## Run Tests (Two Terminals)

Terminal A (Host):

```bash
maestro --device 394C4328-6DC1-4BDD-827F-88E444EC593F test maestro-scripts/host_flow.yaml
```

Terminal B (Peer):

```bash
maestro --device 4DC394C5-AB52-44E4-80AA-F860F074C8F9 test maestro-scripts/peer_flow.yaml
```

To find booted device IDs:

```bash
xcrun simctl list devices booted
```

If you want to shard tests across multiple devices, see Maestro’s `--shard-all` / `--shard-split` options.

## Add a New Scenario

1. Duplicate a flow file (e.g., `peer_flow.yaml`).
2. Keep selectors to visible text or accessibility labels.
3. Add `waitFor` or `assertVisible` for state transitions.

## Known Limitations

- Uses explicit accessibility identifiers for stable selectors.
- Apple Music authorization must be satisfied for search to return results.
- If simulator device names differ, update commands or `setup.sh` defaults.

## Accessibility Identifiers

These identifiers are present in the app for automation:

- `host_start_session_button`
- `peer_join_session_button`
- `song_search_field`
- `add_song_button`
- `shared_queue_view`
- `song_row_<id>`

TODO: Add a stable `confirmation_message` identifier when a visible confirmation UI exists.
