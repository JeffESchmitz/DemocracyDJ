#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE_ID=${APP_BUNDLE_ID:-com.jeffschmitz.DemocracyDJ}
APP_PATH=${APP_PATH:-""}
HOST_DEVICE_NAME=${HOST_DEVICE_NAME:-"iPhone 17 Pro Max"}
PEER_DEVICE_NAME=${PEER_DEVICE_NAME:-"iPhone 17 Pro"}

if [[ -z "$APP_PATH" ]]; then
  echo "APP_PATH is required. Example:" >&2
  echo "  APP_PATH=~/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug-iphonesimulator/DemocracyDJ.app" >&2
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "APP_PATH not found: $APP_PATH" >&2
  exit 1
fi

find_udid() {
  local name="$1"
  xcrun simctl list devices available | awk -v name="$name" '$0 ~ name {print $(NF-1); exit}'
}

HOST_UDID=$(find_udid "$HOST_DEVICE_NAME")
PEER_UDID=$(find_udid "$PEER_DEVICE_NAME")

if [[ -z "$HOST_UDID" ]]; then
  echo "Host simulator not found: $HOST_DEVICE_NAME" >&2
  exit 1
fi

if [[ -z "$PEER_UDID" ]]; then
  echo "Peer simulator not found: $PEER_DEVICE_NAME" >&2
  exit 1
fi

echo "Booting simulators..."
xcrun simctl boot "$HOST_UDID" || true
xcrun simctl boot "$PEER_UDID" || true

xcrun simctl bootstatus "$HOST_UDID" -b
xcrun simctl bootstatus "$PEER_UDID" -b

echo "Installing app..."
xcrun simctl install "$HOST_UDID" "$APP_PATH"
xcrun simctl install "$PEER_UDID" "$APP_PATH"

echo "Launching app..."
xcrun simctl launch "$HOST_UDID" "$APP_BUNDLE_ID"
xcrun simctl launch "$PEER_UDID" "$APP_BUNDLE_ID"

echo "Done. Host: $HOST_DEVICE_NAME ($HOST_UDID), Peer: $PEER_DEVICE_NAME ($PEER_UDID)"
