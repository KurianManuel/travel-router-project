#!/bin/bash

VPN_IF="wg0"
WAN_IF="wlan0"
WATCHDOG_SERVICE="watchdog-tier1.service"
OPEN_MARKER="/run/vpn-gateway/open.active"
MAX_AGE=180

log() { logger -t watchdog-armer "$1"; }

# VPN interface must exist
if ! ip link show "$VPN_IF" >/dev/null 2>&1; then
  log "wg0 not present, not arming watchdog"
  exit 0
fi

# Handshake freshness
HANDSHAKE_TS=$(wg show "$VPN_IF" latest-handshakes | awk '{print $2}')
NOW=$(date +%s)

if [ "$HANDSHAKE_TS" -eq 0 ]; then
  log "no handshake yet, not arming watchdog"
  exit 0
fi

AGE=$((NOW - HANDSHAKE_TS))
if [ "$AGE" -gt "$MAX_AGE" ]; then
  log "handshake stale (${AGE}s), not arming watchdog"
  exit 0
fi

# OPEN state must be explicit
if [ ! -f "$OPEN_MARKER" ]; then
  log "OPEN marker missing, not arming watchdog"
  exit 0
fi

# Management path must exist (wlan0)
if ! ip link show "$WAN_IF" >/dev/null 2>&1; then
  log "wlan0 missing, not arming watchdog"
  exit 0
fi

log "All conditions satisfied, starting watchdog"
systemctl start "$WATCHDOG_SERVICE"

