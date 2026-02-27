#!/bin/bash

VPN_IF="wg0"
WAN_IF="wlan0"
USB_IF="usb0"
AP_IF="wlan1"
OPEN_MARKER="/run/vpn-gateway/open.active"
WATCHDOG_SERVICE="watchdog-tier1.service"
HANDSHAKE_MAX_AGE=180

echo "======================================"
echo " Raspberry Pi Gateway — Status Report "
echo "======================================"
echo

# ---- Interface presence ----

iface_status() {
  if ip link show "$1" >/dev/null 2>&1; then
    echo "  $1 present"
  else
    echo "  $1 missing"
  fi
}

echo "[Interfaces]"
iface_status "$WAN_IF"
iface_status "$USB_IF"
iface_status "$AP_IF"
iface_status "$VPN_IF"
echo

# ---- IP status ----

ip_status() {
  ip -4 addr show "$1" 2>/dev/null | grep -q inet \
    && echo "  $1 has IPv4 address" \
    || echo "  $1 has no IPv4 address"
}

echo "[IP Assignment]"
ip_status "$WAN_IF"
ip_status "$USB_IF"
ip_status "$AP_IF"
echo

# ---- Wi-Fi association ----

echo "[Wi-Fi Association]"
if iw dev "$WAN_IF" link 2>/dev/null | grep -q "Connected"; then
  SSID=$(iw dev "$WAN_IF" link | awk -F': ' '/SSID/ {print $2}')
  SIGNAL=$(iw dev "$WAN_IF" link | awk -F': ' '/signal/ {print $2}')
  echo "  Connected to SSID: $SSID"
  echo "  Signal: $SIGNAL"
else
  echo "  Not associated"
fi
echo

# ---- VPN status ----

echo "[VPN Status]"
if ip link show "$VPN_IF" >/dev/null 2>&1; then
  HANDSHAKE_TS=$(wg show "$VPN_IF" latest-handshakes | awk '{print $2}')
  if [ -n "$HANDSHAKE_TS" ] && [ "$HANDSHAKE_TS" -ne 0 ]; then
    NOW=$(date +%s)
    AGE=$((NOW - HANDSHAKE_TS))
    echo "  wg0 present"
    echo "  Last handshake: ${AGE}s ago"
    if [ "$AGE" -le "$HANDSHAKE_MAX_AGE" ]; then
      echo "    Status: HEALTHY"
    else
      echo "    Status: STALE"
    fi
  else
    echo "  wg0 present but no handshake yet"
  fi
else
  echo "  wg0 missing"
fi
echo

# ---- Firewall intent ----

echo "[Firewall Intent]"
if [ -f "$OPEN_MARKER" ]; then
    echo "  OPEN state declared (VPN routing intended)"
elif [ -f "/run/vpn-gateway/lockdown.active" ]; then
    echo "  LOCKDOWN state (fail-closed)"
else
    echo "  UNKNOWN state"
fi
echo

# ---- Watchdog status ----

echo "[Watchdog Status]"
if systemctl is-active --quiet "$WATCHDOG_SERVICE"; then
  echo "  Watchdog armed and running"
elif systemctl is-failed --quiet "$WATCHDOG_SERVICE"; then
  echo "  Watchdog service failed"
else
  echo "  Watchdog not active"
fi
echo

# ---- DHCP status ----

echo "[DHCP Status]"
if systemctl is-active --quiet dnsmasq; then
    echo "  dnsmasq service running"
    
    # Check DHCP configuration
    if grep -q "interface=usb0" /etc/dnsmasq.conf 2>/dev/null; then
        echo "  DHCP configured on usb0"
        
        # Show DHCP range
        DHCP_RANGE=$(grep "^dhcp-range" /etc/dnsmasq.conf | head -1)
        if [ -n "$DHCP_RANGE" ]; then
            echo "    Range: $DHCP_RANGE"
        fi
    else
        echo "  DHCP not configured for usb0"
    fi
    
    # Show active leases
    if [ -f /var/lib/misc/dnsmasq.leases ]; then
        LEASE_COUNT=$(wc -l < /var/lib/misc/dnsmasq.leases)
        if [ "$LEASE_COUNT" -gt 0 ]; then
            echo "  Active DHCP leases: $LEASE_COUNT"
            echo ""
            echo "  [Connected Clients]"
            while read -r LEASE_LINE; do
                # dnsmasq.leases format: timestamp MAC IP hostname clientid
                LEASE_IP=$(echo "$LEASE_LINE" | awk '{print $3}')
                LEASE_MAC=$(echo "$LEASE_LINE" | awk '{print $2}')
                LEASE_HOSTNAME=$(echo "$LEASE_LINE" | awk '{print $4}')
                LEASE_TIME=$(echo "$LEASE_LINE" | awk '{print $1}')
                
                # Convert timestamp to readable format
                if [ "$LEASE_TIME" != "0" ]; then
                    LEASE_DATE=$(date -d "@$LEASE_TIME" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "N/A")
                else
                    LEASE_DATE="Infinite"
                fi
                
                echo "    • IP: $LEASE_IP"
                echo "      MAC: $LEASE_MAC"
                [ "$LEASE_HOSTNAME" != "*" ] && echo "      Hostname: $LEASE_HOSTNAME"
                echo "      Lease expires: $LEASE_DATE"
                echo ""
            done < /var/lib/misc/dnsmasq.leases
        else
            echo "  No active DHCP leases"
        fi
    else
        echo "  No lease file found"
    fi
else
    echo "  dnsmasq service not running"
fi
echo

# ---- Management access ----

echo "[Management Access]"
ip link show "$USB_IF" >/dev/null 2>&1 \
  && echo "  SSH via USB possible" \
  || echo "  USB SSH unavailable"

ip link show "$WAN_IF" >/dev/null 2>&1 \
  && echo "  SSH via Wi-Fi possible" \
  || echo "  Wi-Fi SSH unavailable"

echo
echo "This script is informational only."
echo "No enforcement decisions are made here."
echo
