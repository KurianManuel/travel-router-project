#!/bin/bash
set -e

# ---------- Interfaces ----------
VPN_IF="wg0"
WAN_IF="wlan0"
USB_IF="usb0"
AP_IF="wlan1"

STATE_DIR="/run/vpn-gateway"

echo "[+] Opening firewall for VPN-only routing"

# ---------- Enable forwarding ----------
sysctl -w net.ipv4.ip_forward=1 >/dev/null

# ---------- Hard reset ----------
iptables -F
iptables -t nat -F
iptables -X

# ---------- Default policies (fail-closed) ----------
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# ---------- INPUT (management plane) ----------
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# SSH over USB (if present)
iptables -A INPUT -i "$USB_IF" -p tcp --dport 22 -j ACCEPT

# SSH over upstream Wi-Fi (hard guarantee)
iptables -A INPUT -i "$WAN_IF" -p tcp --dport 22 -j ACCEPT

# Explicitly block SSH from AP
iptables -A INPUT -i "$AP_IF" -p tcp --dport 22 -j DROP

# DHCP + DNS for AP (future-safe)
iptables -A INPUT -i "$AP_IF" -p udp --dport 67:68 -j ACCEPT
iptables -A INPUT -i "$AP_IF" -p udp --dport 53 -j ACCEPT
iptables -A INPUT -i "$AP_IF" -p tcp --dport 53 -j ACCEPT

# Allow web interface connections
iptables -A INPUT -i "$USB_IF" -p tcp --dport 80 -j ACCEPT

# ---------- OUTPUT ----------
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -o "$VPN_IF" -j ACCEPT

# VPN handshake + DNS bootstrap on WAN
iptables -A OUTPUT -o "$WAN_IF" -p udp --dport 51820 -j ACCEPT
iptables -A OUTPUT -o "$WAN_IF" -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -o "$WAN_IF" -p tcp --dport 53 -j ACCEPT

# Allow web interface on USB
iptables -A OUTPUT -o "$USB_IF" -p tcp --sport 80 -j ACCEPT
iptables -A OUTPUT -o "$USB_IF" -p tcp --sport 443 -j ACCEPT

# ---------- FORWARD (data plane) ----------
iptables -A FORWARD -i "$USB_IF" -o "$VPN_IF" -j ACCEPT
iptables -A FORWARD -i "$AP_IF"  -o "$VPN_IF" -j ACCEPT
iptables -A FORWARD -i "$VPN_IF" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# HARD BLOCKS (no leaks, no pivots)
iptables -A FORWARD -o "$WAN_IF" -j DROP
iptables -A FORWARD -i "$AP_IF" -j DROP

# ---------- NAT ----------
iptables -t nat -A POSTROUTING -o "$VPN_IF" -j MASQUERADE

# ---------- STATE ----------
mkdir -p "$STATE_DIR"
touch "$STATE_DIR/open.active"

# Arm watchdog (safe if it fails)
systemctl start watchdog-armer.service || true

echo "[✓] Firewall OPEN state applied safely"

