#!/bin/bash
# DNS Checker Control Script
# Location: /usr/local/bin/dns-checker-ctl.sh

STATE_DIR="/run/dns-checker"
LOG_FILE="/var/log/dns-checker.log"

case "$1" in
    check)
        echo "Running DNS integrity check..."
        /usr/local/sbin/dns-checker.py --once
        ;;
    
    status)
        echo "=== DNS Checker Status ==="
        echo ""
        
        # Timer status
        echo "Timer Status:"
        systemctl status dns-checker.timer --no-pager -l | head -10
        echo ""
        
        # Last check time
        if systemctl is-active dns-checker.timer >/dev/null 2>&1; then
            echo "Next check:"
            systemctl list-timers dns-checker.timer --no-pager
        fi
        echo ""
        ;;
    
    logs)
        echo "=== Recent DNS Checker Logs ==="
        tail -50 "$LOG_FILE" 2>/dev/null || echo "No logs found"
        ;;
    
    enable)
        echo "Enabling DNS integrity checking..."
        sudo systemctl enable --now dns-checker.timer
        echo "✓ DNS checker enabled (runs every 5 minutes)"
        ;;
    
    disable)
        echo "Disabling DNS integrity checking..."
        sudo systemctl disable --now dns-checker.timer
        echo "✓ DNS checker disabled"
        ;;
    
    test)
        echo "=== Testing DNS Integrity Checker ==="
        echo ""
        echo "This will perform a real DNS check."
        echo ""
        /usr/local/sbin/dns-checker.py --once
        echo ""
        echo "Check complete. See logs above for results."
        ;;
    
    *)
        echo "DNS Checker Control Script"
        echo ""
        echo "Usage: $0 {check|status|logs|enable|disable|test}"
        echo ""
        echo "Commands:"
        echo "  check    - Run DNS integrity check now"
        echo "  status   - Show timer status and next check time"
        echo "  logs     - Show recent check logs"
        echo "  enable   - Enable periodic checking (every 5 minutes)"
        echo "  disable  - Disable periodic checking"
        echo "  test     - Run a test check with verbose output"
        echo ""
        exit 1
        ;;
esac
