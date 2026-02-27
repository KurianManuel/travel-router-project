#!/bin/bash
set -e

VPN_IF="wg0"
USB_IF="usb0"
WAN_IF="wlan0"
AP_IF="wlan1"

echo "[!] LOCKDOWN: fail-closed, management preserved"

# Disable forwarding
sysctl -w net.ipv4.ip_forward=0 >/dev/null

# Flush rules
iptables -F
iptables -t nat -F
iptables -X

# Default policies
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# ---------- INPUT (MANAGEMENT) ----------

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -i "$USB_IF" -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# SSH over USB (if present)
iptables -A INPUT -i "$USB_IF" -p tcp --dport 22 -j ACCEPT

# SSH over upstream Wi-Fi (hard guarantee)
iptables -A INPUT -i "$WAN_IF" -p tcp --dport 22 -j ACCEPT

# Explicitly block SSH from AP
iptables -A INPUT -i "$AP_IF" -p tcp --dport 22 -j DROP

# ---------- OUTPUT ----------

iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow VPN recovery + DNS only
iptables -A OUTPUT -o "$WAN_IF" -p udp --dport 51820 -j ACCEPT
iptables -A OUTPUT -o "$WAN_IF" -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -o "$WAN_IF" -p tcp --dport 53 -j ACCEPT

# Allow responses back to USB (for web interface in lockdown)
iptables -A OUTPUT -o "$USB_IF" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Stop watchdog (no monitoring needed in lockdown)
systemctl stop watchdog-tier1.service 2>/dev/null || true

mkdir -p /run/vpn-gateway
touch /run/vpn-gateway/lockdown.active
rm -f /run/vpn-gateway/open.active

echo "[✓] LOCKDOWN active — SSH safe (USB + Wi-Fi), internet blocked"

