#!/bin/bash

CHECK_INTERVAL=10
HANDSHAKE_MAX_AGE=180   # seconds
VPN_IF="wg0"
LOCKDOWN="/usr/local/sbin/lockdown.sh"

log() {
    logger -t vpn-watchdog "$1"
}

LOCKED=0

while true; do
    # 1. VPN interface must exist
    if ! ip link show "$VPN_IF" >/dev/null 2>&1; then
        if [ "$LOCKED" -eq 0 ]; then
            log "wg0 missing — triggering lockdown"
            $LOCKDOWN
            LOCKED=1
        fi
        sleep "$CHECK_INTERVAL"
        continue
    fi

    # 2. Handshake freshness
    HANDSHAKE_TS=$(wg show "$VPN_IF" latest-handshakes | awk '{print $2}')
    NOW=$(date +%s)

    if [ "$HANDSHAKE_TS" -eq 0 ]; then
        if [ "$LOCKED" -eq 0 ]; then
            log "No handshake recorded — triggering lockdown"
            $LOCKDOWN
            LOCKED=1
        fi
        sleep "$CHECK_INTERVAL"
        continue
    fi

    AGE=$((NOW - HANDSHAKE_TS))

    if [ "$AGE" -gt "$HANDSHAKE_MAX_AGE" ]; then
        if [ "$LOCKED" -eq 0 ]; then
            log "Handshake stale (${AGE}s) — triggering lockdown"
            $LOCKDOWN
            LOCKED=1
        fi
        sleep "$CHECK_INTERVAL"
        continue
    fi

    # VPN healthy
    LOCKED=0
    sleep "$CHECK_INTERVAL"
done

