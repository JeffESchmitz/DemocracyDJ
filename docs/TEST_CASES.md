# Test Cases

## Ordering Rules (Read First)

- Every test case MUST have a stable ID using the format `<Group>-<Number>` (example: `Guest-1`).
- Groups are limited to: `Mode`, `Host`, `Guest`, `Connect`, `Music`, `Shared`.
- Numbering is sequential within each group and never reused.
- Sections are ordered by app flow: Mode → Host → Guest → Connect → Music → Shared.
- When adding a new case, append to the correct group and increment its number.

This document tracks manual test cases with step-by-step reproduction.

## Mode

### Mode-1: Display Name Required

1. Launch the app.
2. Leave the display name empty (or only whitespace).
3. Confirm the Host/Guest buttons are disabled.

### Mode-2: Display Name Enables Mode Buttons

1. Launch the app.
2. Enter a non-empty display name.
3. Confirm the Host/Guest buttons become enabled.

### Mode-3: Start Host Session

1. Enter a display name.
2. Tap “I’m Driving”.
3. Confirm the app transitions to the Host screen.

### Mode-4: Host Starts Hosting

1. Enter a display name.
2. Tap “I’m Driving”.
3. Confirm hosting starts (status badge shows hosting active).

### Mode-5: Start Guest Session

1. Enter a display name.
2. Tap “I’m a Passenger”.
3. Confirm the app transitions to the Guest screen.

### Mode-6: Guest Starts Browsing

1. Enter a display name.
2. Tap “I’m a Passenger”.
3. Confirm browsing starts (status shows browsing/connecting).

## Host

### Host-1: Queue Ordering Is Stable on Ties

1. Host has at least two queued songs with equal vote counts.
2. Cast a vote to create a tie (or maintain a tie).
3. Confirm the queue ordering remains stable for tied items.

### Host-2: Add Song From Search

1. Tap “Add”.
2. Search for a song and select a result not in the queue or now playing.
3. Confirm the song is added to the queue.

### Host-3: Host Search Results Load After Debounce

1. Tap “Add”.
2. Type a query and confirm results appear after a brief debounce.

### Host-4: Duplicate Song Not Added

1. Tap “Add”.
2. Search for a song already in the queue or now playing.
3. Confirm the result is disabled or marked as already added.
4. Try selecting it and confirm it is not added to the queue.

### Host-5: Host Search Empty State

1. Tap “Add”.
2. Enter a query that yields no results.
3. Confirm the empty state is shown.

### Host-6: Host Search Error Alert

1. Tap “Add”.
2. Induce a search failure (e.g., disable network).
3. Confirm a search error alert appears.

### Host-7: Dismiss Search Clears State

1. Tap “Add”.
2. Enter a query and wait for results.
3. Dismiss the sheet.
4. Reopen “Add” and confirm query/results are cleared.

## Guest

### Guest-1: GuestSearchSheet - Previews

1. Open `ios/DemocracyDJ/Features/Guest/GuestSearchSheet.swift`.
2. Show the SwiftUI canvas.
3. Verify preview states:
   - Empty State
   - Searching
   - With Results
   - Error

### Guest-2: Guest Search - Simulator Flow

1. Build and run the app on a simulator.
2. Enter a display name on Mode Selection.
3. Choose “I’m a Passenger”.
4. Connect to a host in “Nearby Parties”.
5. Tap “Suggest a Song”.
6. Confirm the search sheet opens.

### Guest-3: Vote Sends Intent and Clears Pending

1. Connect to a host with a populated queue.
2. Tap the vote button for a song.
3. Confirm the vote shows as pending.
4. Wait for the next host snapshot update.
5. Confirm pending vote clears and counts reflect the update.

### Guest-4: Guest Search Results Load

1. Connect to a host.
2. Tap “Suggest a Song”.
3. Type at least 2 characters.
4. Confirm results load after a brief debounce.

### Guest-5: Suggest Song Sends Intent

1. Connect to a host.
2. Tap “Suggest a Song”.
3. Type at least 2 characters and wait for results.
4. Select a song; confirm the sheet dismisses and the suggestion sends.

### Guest-6: Dismiss Suggest Sheet Resets State

1. Connect to a host.
2. Tap “Suggest a Song”.
3. Enter a query and wait for results.
4. Dismiss the sheet.
5. Reopen the sheet and confirm query/results are cleared.

### Guest-7: Guest Voting UI (One Vote Per Song)

1. Connect to a host with a populated queue.
2. Verify each queue row shows a vote button and count.
3. Tap the vote button on a song.
4. Confirm the button switches to filled/blue and becomes disabled.
5. Confirm the vote count increases after the next host snapshot.

## Connect

### Connect-1: Guest Discovery and Connect

1. Start a host session on a second device.
2. On the guest, confirm nearby hosts appear without duplicates.
3. Tap a host; confirm the status changes to connecting, then connected.

### Connect-2: Host Snapshot Broadcasts on Change

1. Connect a guest to the host.
2. On host, add a song or skip to change now playing/queue.
3. Confirm the guest updates promptly after each change.

### Connect-3: Guest Disconnect Resets State

1. Connect a guest to a host and cast a vote.
2. Force a disconnect (host stops or guest exits).
3. Confirm the guest returns to disconnected state.
4. Confirm host snapshot and pending votes are cleared.

### Connect-4: Host Snapshot Sent on Reconnect

1. Connect a guest to the host.
2. Disconnect the guest (host stops or guest exits).
3. Reconnect the guest to the host.
4. Confirm the guest receives a full snapshot on reconnect.

## Music

### Music-1: Playback Controls (Authorized + Subscribed)

1. Ensure Apple Music is authorized and subscribed.
2. Start playback from the host.
3. Confirm pause stops playback.

### Music-2: Playback Gating

1. Ensure Apple Music is not authorized.
2. Tap play; confirm “Music Access Required” alert.
3. Authorize Apple Music but remove subscription access.
4. Tap play; confirm “Subscription Required” alert.

### Music-3: Auto-Advance on Song Finish

1. Start playback with a non-empty queue.
2. Let the current song finish.
3. Confirm the next queued song becomes now playing.

### Music-4: Skip Advances Queue When Non-Empty

1. Ensure a non-empty queue.
2. Tap skip.
3. Confirm the next queued song becomes now playing.

### Music-5: Skip Clears Now Playing When Queue Empty

1. Ensure the queue is empty and a song is playing.
2. Tap skip.
3. Confirm now playing clears.

## Shared

### Shared-1: Exit Session Returns to Mode Selection

1. Enter a host or guest session.
2. Tap the “X” exit button.
3. Confirm networking stops and the app returns to mode selection.
