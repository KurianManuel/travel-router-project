#!/bin/bash
# WiFi Connection with VPN Verification
# Location: /usr/local/sbin/wifi-connect.sh

SSID="$1"
BSSID="$2"
PASSWORD="$3"

if [ -z "$SSID" ]; then
    echo '{"success": false, "error": "SSID required"}'
    exit 1
fi

LOG="/var/log/wifi-connect.log"
log() { echo "[$(date)] $1" | tee -a "$LOG" >&2; }

log "=== WiFi Connection: $SSID (BSSID: ${BSSID:-any}) ==="

# Step 0: Save current network for rollback
ORIGINAL_SSID=$(iwgetid -r 2>/dev/null)
ORIGINAL_BSSID=""
if [ -n "$ORIGINAL_SSID" ]; then
    ORIGINAL_BSSID=$(iw dev wlan0 link | grep "Connected to" | awk '{print $3}')
    log "Currently connected to: $ORIGINAL_SSID ($ORIGINAL_BSSID)"
    
    # Check if trying to connect to the same network
    if [ "$ORIGINAL_SSID" = "$SSID" ]; then
        if [ -n "$BSSID" ] && [ "$ORIGINAL_BSSID" = "$BSSID" ]; then
            log "Already connected to this exact network (same BSSID)"
            echo '{"success": false, "error": "Already connected to this network"}'
            exit 1
        fi
        log "WARNING: Connecting to same SSID but different BSSID (roaming)"
    fi
fi

# Step 1: Ensure wlan0 is up and force a fresh scan
log "Bringing up wlan0 and scanning..."
nmcli device set wlan0 managed yes
nmcli device wifi rescan
sleep 3

# Step 2: Check if target network is visible
log "Verifying target network is visible..."
NETWORK_FOUND=false

if [ -n "$BSSID" ]; then
    VISIBLE=$(nmcli -f BSSID device wifi list | grep -i "$BSSID" || true)
    if [ -n "$VISIBLE" ]; then
        NETWORK_FOUND=true
        log "Target BSSID $BSSID found in scan"
    else
        log "WARNING: Target BSSID $BSSID not found, will try SSID only"
        BSSID=""  # Clear BSSID so we connect by SSID
    fi
fi

if [ -z "$BSSID" ]; then
    VISIBLE=$(nmcli -f SSID device wifi list | grep -i "$SSID" || true)
    if [ -n "$VISIBLE" ]; then
        NETWORK_FOUND=true
        log "Target SSID $SSID found in scan"
    fi
fi

if [ "$NETWORK_FOUND" = false ]; then
    log "WARNING: Target network not found in scan results"
    log "Available networks:"
    nmcli device wifi list | tee -a "$LOG" >&2
    log "Proceeding anyway - network may appear during connection attempt"
fi

# Step 3: Disconnect current network
log "Disconnecting current network..."
nmcli device disconnect wlan0 2>/dev/null >&2
sleep 2

# Step 4: Connect to new network
log "Connecting to $SSID..."

# Don't delete saved connections anymore - we'll use temporary connections instead
# This avoids the key-mgmt property missing error

CONNECTION_SUCCESS=false

# Try connecting with BSSID first if provided
# CRITICAL: Remove any existing connection first to avoid conflicts
nmcli connection delete id "$SSID" 2>/dev/null >&2 || true

if [ -n "$BSSID" ] && [ -n "$PASSWORD" ]; then
    log "Attempt 1: Connecting with BSSID and password..."
    nmcli device wifi connect "$BSSID" password "$PASSWORD" 2>&1 | tee -a "$LOG" >&2
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        CONNECTION_SUCCESS=true
        log "BSSID connection succeeded"
    else
        log "BSSID connection failed, will try SSID..."
    fi
elif [ -n "$BSSID" ]; then
    log "Attempt 1: Connecting to open network with BSSID..."
    nmcli device wifi connect "$BSSID" 2>&1 | tee -a "$LOG" >&2
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        CONNECTION_SUCCESS=true
        log "BSSID connection succeeded"
    else
        log "BSSID connection failed, will try SSID..."
    fi
fi

# Fallback to SSID if BSSID failed or wasn't provided
if [ "$CONNECTION_SUCCESS" = false ]; then
    if [ -n "$PASSWORD" ]; then
        log "Attempt 2: Connecting with SSID and password..."
        nmcli device wifi connect "$SSID" password "$PASSWORD" 2>&1 | tee -a "$LOG" >&2
    else
        log "Attempt 2: Connecting to open network with SSID..."
        nmcli device wifi connect "$SSID" 2>&1 | tee -a "$LOG" >&2
    fi
fi

if [ $? -ne 0 ]; then
    log "ERROR: Connection failed"
    
    # Try to reconnect to original network
    if [ -n "$ORIGINAL_SSID" ]; then
        log "Connection failed, reconnecting to $ORIGINAL_SSID..."
        nmcli device wifi connect "$ORIGINAL_SSID" 2>&1 | tee -a "$LOG" >&2
    fi
    
    echo '{"success": false, "error": "Failed to connect to network"}'
    exit 1
fi

log "Connected to WiFi, waiting for DHCP..."
# NetworkManager's DHCP client can take 10-15 seconds on slow networks
# We've confirmed dhclient works, so this is just a timing issue
sleep 15

# Step 3: Test internet
log "Checking for IP address..."

# First check if we got an IP
IP_ADDR=$(ip -4 addr show wlan0 | grep inet | awk '{print $2}')
log "wlan0 IP: ${IP_ADDR:-none}"

if [ -z "$IP_ADDR" ]; then
    log "ERROR: No IP address assigned"
    log "DHCP failed - attempting to reconnect to original network"
    
    if [ -n "$ORIGINAL_SSID" ]; then
        log "Reconnecting to $ORIGINAL_SSID (using SSID, not BSSID)..."
        # Use SSID for rollback, not BSSID (BSSID may have changed)
        nmcli device wifi connect "$ORIGINAL_SSID" 2>&1 | tee -a "$LOG" >&2
        sleep 5
        
        # Check if rollback worked
        ROLLBACK_IP=$(ip -4 addr show wlan0 | grep inet | awk '{print $2}')
        if [ -n "$ROLLBACK_IP" ]; then
            log "Successfully rolled back to $ORIGINAL_SSID (IP: $ROLLBACK_IP)"
        else
            log "WARNING: Rollback may have failed, check connection manually"
        fi
    fi
    
    echo '{"success": false, "error": "Failed to get IP address from new network. Attempted to reconnect to previous network.", "dhcp_failed": true}'
    exit 1
fi

# Check default route
DEFAULT_ROUTE=$(ip route | grep default | grep wlan0)
log "Default route: ${DEFAULT_ROUTE:-none}"

if [ -z "$DEFAULT_ROUTE" ]; then
    log "WARNING: No default route via wlan0"
fi

RETRIES=0
MAX_RETRIES=3
INTERNET_OK=false

while [ $RETRIES -lt $MAX_RETRIES ]; do
    log "Ping attempt $((RETRIES + 1)) to 1.1.1.1..."
    if ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
        INTERNET_OK=true
        log "Ping successful"
        break
    fi
    RETRIES=$((RETRIES + 1))
    if [ $RETRIES -lt $MAX_RETRIES ]; then
        sleep 2
    fi
done

if [ "$INTERNET_OK" = false ]; then
    log "ERROR: No internet access after $MAX_RETRIES attempts"
    log "This network may require captive portal login or has no internet gateway"
    echo '{"success": false, "error": "Connected to WiFi but no internet access. Network may require web-based login (captive portal) or has no internet gateway.", "connected_but_no_internet": true}'
    exit 1
fi

log "Internet access confirmed"

# Step 4: Restart WireGuard
log "Restarting WireGuard VPN..."
systemctl restart wg-quick@wg0
sleep 4

# Step 5: Verify VPN interface exists
if ! ip link show wg0 >/dev/null 2>&1; then
    log "ERROR: wg0 interface not up"
    echo '{"success": false, "error": "VPN interface failed to start"}'
    exit 1
fi

# Step 6: Check VPN handshake
HANDSHAKE=$(wg show wg0 latest-handshakes 2>/dev/null | awk '{print $2}')
if [ -z "$HANDSHAKE" ] || [ "$HANDSHAKE" -eq 0 ] 2>/dev/null; then
    log "ERROR: No VPN handshake"
    echo '{"success": false, "error": "VPN handshake failed - cannot establish secure connection"}'
    exit 1
fi

log "VPN handshake successful"

# Step 7: Apply OPEN firewall state
log "Enabling VPN-only routing..."
/usr/local/sbin/firewall-open-vpn.sh >/dev/null 2>&1

log "=== Connection complete ==="

# Output JSON response (this must be the ONLY thing on stdout for the API to parse)
echo "{\"success\": true, \"ssid\": \"$SSID\", \"vpn_established\": true}"
exit 0
