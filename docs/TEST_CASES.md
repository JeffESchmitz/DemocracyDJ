# Test Cases

This document tracks manual test cases with step-by-step reproduction.

## Ordering Rules (Read First)

- Every test case MUST have a stable ID using the format `<Group>-<Number>` (example: `Guest-1`).
- Groups are limited to: `Mode`, `Host`, `Guest`, `Connect`, `Music`, `Shared`.
- Numbering is sequential within each group and never reused.
- Sections are ordered by app flow: Mode → Host → Guest → Connect → Music → Shared.
- When adding a new case, append to the correct group and increment its number.

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
6. Type a query (>= 2 characters).
7. Confirm results load and selecting a song dismisses the sheet.
