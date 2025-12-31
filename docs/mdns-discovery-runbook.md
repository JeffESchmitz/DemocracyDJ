# Bonjour Discovery Runbook (democracy-dj)

## Goal
Verify that MultipeerConnectivity advertising and browsing are working by observing Bonjour service discovery for `_democracy-dj._tcp` and `_democracy-dj._udp`.

## Prereqs
- Host app is running and has started advertising.
- Guest app is running and has started browsing.
- Both devices/simulators are on the same network.

## Quick Checks (macOS)
1) Browse for services:
```bash
dns-sd -B _democracy-dj._tcp
```
2) If you see a service instance, resolve it:
```bash
dns-sd -L "<service-instance-name>" _democracy-dj._tcp
```
3) Repeat for UDP if needed:
```bash
dns-sd -B _democracy-dj._udp
```

## What “Good” Looks Like
- `dns-sd -B` shows one or more instances after host starts advertising.
- `dns-sd -L` returns a host and port without timing out.

## Common Failure Modes
- No services listed: host isn’t advertising, wrong service type, or devices not on same network.
- Services listed but resolution fails: firewall or local network permission issue.

## Notes
- The service type must be exactly `democracy-dj` in code and Info.plist.
- On iOS 14+, Local Network permission is required for discovery.
