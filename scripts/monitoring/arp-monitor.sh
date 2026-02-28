#!/bin/bash
# ARP Spoofing / MITM Detection Monitor
# Location: /usr/local/sbin/arp-monitor.sh
# Monitors gateway MAC address for unexpected changes

set -e

INTERFACE="wlan0"
CHECK_INTERVAL=5  # seconds
STATE_DIR="/run/arp-monitor"
STATE_FILE="$STATE_DIR/gateway-mac"
LOG_FILE="/var/log/arp-monitor.log"
KILL_SWITCH="/usr/local/sbin/lockdown.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE" >&2
}

get_gateway_ip() {
    # Get default gateway IP for wlan0
    ip route | grep "^default.*$INTERFACE" | awk '{print $3}'
}

get_gateway_mac() {
    # Get MAC address for gateway IP from ARP table
    local gateway_ip="$1"
    
    # First try ip neigh (newer)
    local mac=$(ip neigh show "$gateway_ip" dev "$INTERFACE" | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -n1)
    
    # Fallback to arp command
    if [ -z "$mac" ]; then
        mac=$(arp -n "$gateway_ip" | grep "$gateway_ip" | awk '{print $3}' | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}')
    fi
    
    echo "$mac"
}

trigger_kill_switch() {
    local reason="$1"
    log "CRITICAL: $reason"
    log "Triggering kill switch..."
    
    # Save incident details for recovery
    mkdir -p "$STATE_DIR"
    cat > "$STATE_DIR/incident.json" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "reason": "ARP_SPOOFING",
    "details": "$reason",
    "interface": "$INTERFACE"
}
EOF
    
    # Trigger lockdown
    "$KILL_SWITCH" >/dev/null 2>&1 || true
    
    log "System locked down"
    exit 1
}

# Main monitoring loop
log "=== ARP Monitor Starting ==="

# Ensure state directory exists
mkdir -p "$STATE_DIR"

# Wait for network to be up
log "Waiting for network to be ready..."
sleep 5

while true; do
    # Check if interface is up
    if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
        log "Interface $INTERFACE not found, waiting..."
        sleep "$CHECK_INTERVAL"
        continue
    fi
    
    if ! ip link show "$INTERFACE" | grep -q "state UP"; then
        log "Interface $INTERFACE is down, waiting..."
        rm -f "$STATE_FILE"  # Clear learned MAC when interface goes down
        sleep "$CHECK_INTERVAL"
        continue
    fi
    
    # Get gateway IP
    GATEWAY_IP=$(get_gateway_ip)
    
    if [ -z "$GATEWAY_IP" ]; then
        log "No default gateway found, waiting..."
        rm -f "$STATE_FILE"
        sleep "$CHECK_INTERVAL"
        continue
    fi
    
    # Get current gateway MAC
    CURRENT_MAC=$(get_gateway_mac "$GATEWAY_IP")
    
    if [ -z "$CURRENT_MAC" ]; then
        log "Gateway MAC not in ARP table yet, waiting..."
        sleep "$CHECK_INTERVAL"
        continue
    fi
    
    # Normalize MAC to lowercase
    CURRENT_MAC=$(echo "$CURRENT_MAC" | tr '[:upper:]' '[:lower:]')
    
    # Check if we have a learned MAC
    if [ -f "$STATE_FILE" ]; then
        LEARNED_MAC=$(cat "$STATE_FILE")
        
        # Compare MACs
        if [ "$CURRENT_MAC" != "$LEARNED_MAC" ]; then
            trigger_kill_switch "ARP spoofing detected! Gateway MAC changed from $LEARNED_MAC to $CURRENT_MAC (Gateway IP: $GATEWAY_IP)"
        fi
        
        # MAC is still the same, all good
        # log "Gateway MAC verified: $CURRENT_MAC (Gateway: $GATEWAY_IP)"
        
    else
        # First time seeing this gateway, learn its MAC
        log "Learning gateway MAC: $CURRENT_MAC (Gateway IP: $GATEWAY_IP)"
        echo "$CURRENT_MAC" > "$STATE_FILE"
        log "Baseline established - now monitoring for changes"
    fi
    
    sleep "$CHECK_INTERVAL"
done
