# MultipeerConnectivity Logging Runbook

## Goal
Capture useful logs for discovery, connection, and message flow in a MultipeerConnectivity session.

## Console.app (macOS)
1) Open Console.app.
2) Select the device or simulator in the sidebar.
3) Use a filter such as:
   - `subsystem:com.apple.MultipeerConnectivity`
   - `process:DemocracyDJ`
4) Start Host/Guest flows and watch for discovery/connection messages.

## log stream (CLI)
Use system logging with predicates:
```bash
log stream --info --predicate 'subsystem == "com.apple.MultipeerConnectivity"'
```
Optionally filter your app process:
```bash
log stream --info --predicate 'process == "DemocracyDJ"'
```

## PacketLogger (Apple Additional Tools)
1) Install “Additional Tools for Xcode” from Apple Developer downloads.
2) Launch PacketLogger.
3) Start capture on Wi-Fi or Bluetooth as needed.
4) Reproduce the discovery/connection flow and inspect mDNS traffic.

## tcpdump / Wireshark (mDNS)
To check mDNS broadcasts on macOS:
```bash
sudo tcpdump -n -vvv -i en0 udp port 5353
```
Look for `_democracy-dj` service queries and responses.

## What “Good” Looks Like
- Discovery logs appear when host starts advertising and guest starts browsing.
- Connection logs show invitation accepted and session connected.
- Message send/receive logs correspond to MultipeerEvent emissions.

## Notes
- MultipeerConnectivity session traffic is encrypted; packet capture will not decode message payloads.
- Ensure Local Network permission is granted on iOS.
