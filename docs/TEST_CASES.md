# Test Cases

This document tracks manual test cases with step-by-step reproduction.

## Guest Search (Issue #70)

### GuestSearchSheet - Previews

1. Open `ios/DemocracyDJ/Features/Guest/GuestSearchSheet.swift`.
2. Show the SwiftUI canvas.
3. Verify preview states:
   - Empty State
   - Searching
   - With Results
   - Error

### Guest Search - Simulator Flow

1. Build and run the app on a simulator.
2. Enter a display name on Mode Selection.
3. Choose “I’m a Passenger”.
4. Connect to a host in “Nearby Parties”.
5. Tap “Suggest a Song”.
6. Type a query (>= 2 characters).
7. Confirm results load and selecting a song dismisses the sheet.
