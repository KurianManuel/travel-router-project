#!/bin/bash
# MAC Address Manager for wlan0
# Location: /usr/local/sbin/mac-manager.sh
# Runs at boot before NetworkManager starts WiFi

set -e

INTERFACE="wlan0"
CONFIG_FILE="/etc/mac-manager.conf"
LOG_FILE="/var/log/mac-manager.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== MAC Address Manager Starting ==="

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    # Default configuration
    MODE="random"  # Options: random, clone, persistent
    CLONE_MAC=""   # MAC to clone (if mode=clone)
fi

log "Mode: $MODE"

# Ensure interface is down before changing MAC
log "Bringing down $INTERFACE..."
ip link set "$INTERFACE" down 2>/dev/null || true
sleep 1

# Get original MAC for logging
ORIGINAL_MAC=$(cat /sys/class/net/"$INTERFACE"/address 2>/dev/null || echo "unknown")
log "Original MAC: $ORIGINAL_MAC"

case "$MODE" in
    random)
        log "Generating random MAC address..."
        # Generate random MAC with locally administered bit set
        # First byte: 02, 06, 0a, 0e (locally administered, unicast)
        FIRST_BYTE=$(printf "0%x" $((2 + 4 * (RANDOM % 4))))
        NEW_MAC="${FIRST_BYTE}:$(hexdump -n 5 -e '5/1 ":%02x"' /dev/urandom | cut -c 2-)"
        
        log "Generated MAC: $NEW_MAC"
        ip link set dev "$INTERFACE" address "$NEW_MAC"
        ;;
        
    clone)
        if [ -z "$CLONE_MAC" ]; then
            log "ERROR: Clone mode enabled but no MAC specified in $CONFIG_FILE"
            log "Falling back to random mode"
            
            FIRST_BYTE=$(printf "0%x" $((2 + 4 * (RANDOM % 4))))
            NEW_MAC="${FIRST_BYTE}:$(hexdump -n 5 -e '5/1 ":%02x"' /dev/urandom | cut -c 2-)"
            ip link set dev "$INTERFACE" address "$NEW_MAC"
        else
            log "Cloning MAC: $CLONE_MAC"
            ip link set dev "$INTERFACE" address "$CLONE_MAC"
            NEW_MAC="$CLONE_MAC"
        fi
        ;;
        
    persistent)
        if [ -z "$CLONE_MAC" ]; then
            log "ERROR: Persistent mode enabled but no MAC specified"
            log "Using original MAC"
            NEW_MAC="$ORIGINAL_MAC"
        else
            log "Setting persistent MAC: $CLONE_MAC"
            ip link set dev "$INTERFACE" address "$CLONE_MAC"
            NEW_MAC="$CLONE_MAC"
        fi
        ;;
        
    original)
        log "Using original MAC (no change)"
        NEW_MAC="$ORIGINAL_MAC"
        ;;
        
    *)
        log "ERROR: Unknown mode '$MODE' in $CONFIG_FILE"
        log "Using original MAC"
        NEW_MAC="$ORIGINAL_MAC"
        ;;
esac

# Bring interface back up
log "Bringing up $INTERFACE..."
ip link set "$INTERFACE" up
sleep 1

# Verify change
CURRENT_MAC=$(cat /sys/class/net/"$INTERFACE"/address)
log "Current MAC: $CURRENT_MAC"

if [ "$MODE" != "original" ] && [ "$CURRENT_MAC" = "$ORIGINAL_MAC" ]; then
    log "WARNING: MAC address change failed or was reverted"
else
    log "MAC address successfully set"
fi

# Store MAC for other services to read
mkdir -p /run/mac-manager
echo "$CURRENT_MAC" > /run/mac-manager/current-mac
echo "$MODE" > /run/mac-manager/mode

log "=== MAC Address Manager Complete ==="
exit 0
