#!/bin/bash
# ARP Monitor Control Script
# Location: /usr/local/bin/arp-monitor-ctl.sh
# Control and inspect ARP spoofing detection

STATE_DIR="/run/arp-monitor"
STATE_FILE="$STATE_DIR/gateway-mac"
LOG_FILE="/var/log/arp-monitor.log"

case "$1" in
    status)
        echo "=== ARP Monitor Status ==="
        echo ""
        
        # Service status
        echo "Service Status:"
        systemctl status arp-monitor.service --no-pager -l | head -20
        echo ""
        
        # Current gateway
        GATEWAY_IP=$(ip route | grep "^default.*wlan0" | awk '{print $3}')
        if [ -n "$GATEWAY_IP" ]; then
            echo "Current Gateway: $GATEWAY_IP"
            
            # Get MAC from ARP table
            CURRENT_MAC=$(ip neigh show "$GATEWAY_IP" dev wlan0 | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -n1)
            echo "Current Gateway MAC: ${CURRENT_MAC:-Not in ARP table}"
        else
            echo "Current Gateway: Not connected"
        fi
        echo ""
        
        # Learned baseline
        if [ -f "$STATE_FILE" ]; then
            LEARNED_MAC=$(cat "$STATE_FILE")
            echo "Learned Baseline MAC: $LEARNED_MAC"
        else
            echo "Learned Baseline MAC: None (not yet learned)"
        fi
        echo ""
        ;;
        
    reset)
        echo "Resetting learned gateway MAC..."
        rm -f "$STATE_FILE"
        rm -f "$STATE_DIR/incident.json"
        echo "Baseline cleared. Monitor will relearn on next check."
        systemctl restart arp-monitor.service
        ;;
        
    logs)
        echo "=== Recent ARP Monitor Logs ==="
        tail -50 "$LOG_FILE" 2>/dev/null || echo "No logs found"
        ;;
        
    arp-table)
        echo "=== Current ARP Table ==="
        echo ""
        ip neigh show dev wlan0
        echo ""
        echo "Or using arp command:"
        arp -n | grep wlan0
        ;;
        
    test)
        echo "=== Testing ARP Spoofing Detection ==="
        echo ""
        echo "WARNING: This will trigger the kill switch!"
        echo "The system will go into lockdown mode."
        echo ""
        read -p "Continue? (yes/no): " confirm
        
        if [ "$confirm" != "yes" ]; then
            echo "Test cancelled."
            exit 0
        fi
        
        if [ ! -f "$STATE_FILE" ]; then
            echo "ERROR: No baseline learned yet. Connect to WiFi first."
            exit 1
        fi
        
        echo "Simulating ARP spoofing by changing learned MAC..."
        echo "aa:bb:cc:dd:ee:ff" > "$STATE_FILE"
        echo "Fake MAC installed. Monitor should detect this on next check (within 5 seconds)."
        echo ""
        echo "Watch logs:"
        echo "  tail -f $LOG_FILE"
        ;;
        
    *)
        echo "ARP Monitor Control Script"
        echo ""
        echo "Usage: $0 {status|reset|logs|arp-table|test}"
        echo ""
        echo "Commands:"
        echo "  status     - Show current status and learned baseline"
        echo "  reset      - Clear learned MAC (will relearn automatically)"
        echo "  logs       - Show recent monitor logs"
        echo "  arp-table  - Display current ARP table"
        echo "  test       - Trigger a test alarm (WARNING: activates kill switch)"
        echo ""
        exit 1
        ;;
esac
