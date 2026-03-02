#!/usr/bin/env python3
# Location: /usr/local/sbin/system-monitor.py
"""
System Monitor - Lightweight vitals collector
Monitors CPU, memory, storage, network, and temperature
Writes stats to /run/system-monitor/stats.json for web interface
"""

import json
import time
import os
import sys
from datetime import datetime

try:
    import psutil
except ImportError:
    print("ERROR: psutil not installed. Run: pip3 install psutil --break-system-packages")
    sys.exit(1)

# Configuration
STATE_DIR = "/run/system-monitor"
STATE_FILE = f"{STATE_DIR}/stats.json"
UPDATE_INTERVAL = 5  # seconds
NETWORK_INTERFACE = "wlan0"
VPN_INTERFACE = "wg0"

# Ensure state directory exists
os.makedirs(STATE_DIR, exist_ok=True)

def get_cpu_usage():
    """Get CPU usage percentage"""
    return psutil.cpu_percent(interval=1)

def get_memory_usage():
    """Get memory usage details"""
    mem = psutil.virtual_memory()
    return {
        "total_mb": round(mem.total / (1024 * 1024), 1),
        "used_mb": round(mem.used / (1024 * 1024), 1),
        "available_mb": round(mem.available / (1024 * 1024), 1),
        "percent": mem.percent
    }

def get_storage_usage():
    """Get storage usage for root partition"""
    disk = psutil.disk_usage('/')
    return {
        "total_gb": round(disk.total / (1024 * 1024 * 1024), 2),
        "used_gb": round(disk.used / (1024 * 1024 * 1024), 2),
        "free_gb": round(disk.free / (1024 * 1024 * 1024), 2),
        "percent": disk.percent
    }

def get_network_stats(interface):
    """Get network statistics for interface"""
    try:
        net_io = psutil.net_io_counters(pernic=True)
        if interface in net_io:
            stats = net_io[interface]
            return {
                "bytes_sent": stats.bytes_sent,
                "bytes_recv": stats.bytes_recv,
                "packets_sent": stats.packets_sent,
                "packets_recv": stats.packets_recv
            }
    except:
        pass
    return None

def calculate_network_rate(current, previous, interval):
    """Calculate network transfer rate in KB/s"""
    if previous is None or current is None:
        return {"rx_kbps": 0, "tx_kbps": 0}
    
    rx_bytes = current.get("bytes_recv", 0) - previous.get("bytes_recv", 0)
    tx_bytes = current.get("bytes_sent", 0) - previous.get("bytes_sent", 0)
    
    rx_kbps = round((rx_bytes / 1024) / interval, 2)
    tx_kbps = round((tx_bytes / 1024) / interval, 2)
    
    return {"rx_kbps": max(0, rx_kbps), "tx_kbps": max(0, tx_kbps)}

def get_temperature():
    """Get CPU temperature in Celsius"""
    try:
        with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
            temp = float(f.read().strip()) / 1000.0
            return round(temp, 1)
    except:
        return None

def get_wifi_signal():
    """Get WiFi signal strength"""
    try:
        with open(f'/sys/class/net/{NETWORK_INTERFACE}/operstate', 'r') as f:
            state = f.read().strip()
            if state != 'up':
                return None
        
        # Try to get signal from iw
        import subprocess
        result = subprocess.run(
            ['iw', 'dev', NETWORK_INTERFACE, 'link'],
            capture_output=True,
            text=True,
            timeout=2
        )
        
        for line in result.stdout.split('\n'):
            if 'signal:' in line:
                signal = line.split('signal:')[1].strip().split()[0]
                return int(signal)
    except:
        pass
    return None

def get_uptime():
    """Get system uptime in seconds"""
    try:
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = float(f.read().split()[0])
            return round(uptime_seconds, 0)
    except:
        return None

def format_uptime(seconds):
    """Format uptime in human-readable format"""
    if seconds is None:
        return "Unknown"
    
    days = int(seconds // 86400)
    hours = int((seconds % 86400) // 3600)
    minutes = int((seconds % 3600) // 60)
    
    if days > 0:
        return f"{days}d {hours}h {minutes}m"
    elif hours > 0:
        return f"{hours}h {minutes}m"
    else:
        return f"{minutes}m"

def main():
    """Main monitoring loop"""
    print(f"System Monitor started - Interval: {UPDATE_INTERVAL}s")
    print(f"Monitoring: CPU, Memory, Storage, Network, Temperature")
    print(f"Network interfaces: {NETWORK_INTERFACE}, {VPN_INTERFACE}")
    print(f"Output: {STATE_FILE}")
    
    # Previous network stats for rate calculation
    prev_net = None
    prev_vpn = None
    prev_time = time.time()
    
    while True:
        try:
            current_time = time.time()
            interval = current_time - prev_time
            
            # Collect all stats
            cpu_percent = get_cpu_usage()
            memory = get_memory_usage()
            storage = get_storage_usage()
            temperature = get_temperature()
            wifi_signal = get_wifi_signal()
            uptime_seconds = get_uptime()
            
            # Network stats
            current_net = get_network_stats(NETWORK_INTERFACE)
            current_vpn = get_network_stats(VPN_INTERFACE)
            
            net_rate = calculate_network_rate(current_net, prev_net, interval)
            vpn_rate = calculate_network_rate(current_vpn, prev_vpn, interval)
            
            # Build stats dictionary
            stats = {
                "timestamp": datetime.now().isoformat(),
                "cpu": {
                    "percent": round(cpu_percent, 1)
                },
                "memory": memory,
                "storage": storage,
                "network": {
                    "interface": NETWORK_INTERFACE,
                    "rx_kbps": net_rate["rx_kbps"],
                    "tx_kbps": net_rate["tx_kbps"],
                    "total_rx_mb": round(current_net["bytes_recv"] / (1024 * 1024), 2) if current_net else 0,
                    "total_tx_mb": round(current_net["bytes_sent"] / (1024 * 1024), 2) if current_net else 0
                },
                "vpn": {
                    "interface": VPN_INTERFACE,
                    "rx_kbps": vpn_rate["rx_kbps"],
                    "tx_kbps": vpn_rate["tx_kbps"],
                    "total_rx_mb": round(current_vpn["bytes_recv"] / (1024 * 1024), 2) if current_vpn else 0,
                    "total_tx_mb": round(current_vpn["bytes_sent"] / (1024 * 1024), 2) if current_vpn else 0,
                    "active": current_vpn is not None
                },
                "temperature": {
                    "celsius": temperature,
                    "fahrenheit": round((temperature * 9/5) + 32, 1) if temperature else None
                },
                "wifi": {
                    "signal_dbm": wifi_signal,
                    "interface": NETWORK_INTERFACE
                },
                "uptime": {
                    "seconds": uptime_seconds,
                    "formatted": format_uptime(uptime_seconds)
                }
            }
            
            # Write to file atomically
            temp_file = f"{STATE_FILE}.tmp"
            with open(temp_file, 'w') as f:
                json.dump(stats, f, indent=2)
            os.replace(temp_file, STATE_FILE)
            
            # Update previous values
            prev_net = current_net
            prev_vpn = current_vpn
            prev_time = current_time
            
            # Sleep until next interval
            time.sleep(UPDATE_INTERVAL)
            
        except KeyboardInterrupt:
            print("\nSystem Monitor stopped")
            break
        except Exception as e:
            print(f"Error in monitoring loop: {e}")
            time.sleep(UPDATE_INTERVAL)

if __name__ == "__main__":
    main()
