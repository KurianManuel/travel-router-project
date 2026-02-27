#!/bin/bash
# WiFi Scanner with Evil Twin Detection
# Location: /usr/local/sbin/wifi-scanner.sh

INTERFACE="wlan0"
OUTPUT="/tmp/wifi-scan-results.json"

# Bring interface up
ip link set "$INTERFACE" up 2>/dev/null

# Scan - try multiple methods
SCAN_RAW=""
SCAN_SUCCESS=false

# Method 1: iw scan
SCAN_RAW=$(iw dev "$INTERFACE" scan 2>&1)
if [ $? -eq 0 ]; then
    SCAN_SUCCESS=true
else
    # Method 2: Force scan with NetworkManager
    echo "iw scan failed, trying nmcli..." >&2
    nmcli device wifi rescan 2>/dev/null
    sleep 2
    SCAN_RAW=$(iw dev "$INTERFACE" scan 2>&1)
    if [ $? -eq 0 ]; then
        SCAN_SUCCESS=true
    fi
fi

if [ "$SCAN_SUCCESS" = false ]; then
    echo '{"success": false, "error": "WiFi scan failed. Interface may be busy or down."}' > "$OUTPUT"
    exit 1
fi

# Parse with Python
python3 - "$SCAN_RAW" > "$OUTPUT" <<'PYTHON'
import sys, json, re
from collections import defaultdict
from datetime import datetime

networks, current = [], {}

for line in sys.argv[1].split('\n'):
    line = line.strip()
    if line.startswith('BSS '):
        if current: networks.append(current)
        # Parse: "BSS aa:bb:cc:dd:ee:ff(on wlan0)" -> "aa:bb:cc:dd:ee:ff"
        bssid_part = line.split()[1]  # Get second word
        bssid = bssid_part.split('(')[0]  # Split on '(' and take first part
        current = {'bssid': bssid, 'ssid': '', 'signal_dbm': -100, 'channel': 0, 'encryption': 'Unknown'}
    elif line.startswith('SSID:'): current['ssid'] = line.split(':', 1)[1].strip() or '<hidden>'
    elif 'signal:' in line.lower():
        m = re.search(r'(-?\d+\.\d+)\s*dBm', line)
        if m: current['signal_dbm'] = float(m.group(1))
    elif 'freq:' in line.lower():
        m = re.search(r'(\d+)', line)
        if m:
            freq = int(m.group(1))
            if 2412 <= freq <= 2484: current['channel'] = (freq - 2407) // 5
    elif 'RSN:' in line: current['encryption'] = 'WPA2'
    elif 'WPA:' in line and current['encryption'] == 'Unknown': current['encryption'] = 'WPA'
    elif 'capability: ESS' in line and current['encryption'] == 'Unknown': current['encryption'] = 'Open'

if current: networks.append(current)

# Evil twin detection
groups = defaultdict(list)
for n in networks:
    if n['ssid'] and n['ssid'] != '<hidden>': groups[n['ssid']].append(n)
    n['warnings'], n['safety_level'] = [], 'safe'

for ssid, group in groups.items():
    if len(group) > 1:
        encs = set(n['encryption'] for n in group)
        if len(encs) > 1:
            for n in group:
                if n['encryption'] in ['Open', 'WEP']:
                    n['warnings'].append('Evil twin: Same SSID with weak encryption')
                    n['safety_level'] = 'danger'
                else:
                    n['warnings'].append('Multiple encryption types')
                    n['safety_level'] = 'warning'
        
        sigs = [n['signal_dbm'] for n in group]
        avg = sum(sigs) / len(sigs)
        for n in group:
            if n['signal_dbm'] > avg + 15:
                n['warnings'].append('Unusually strong signal')
                if n['safety_level'] == 'safe': n['safety_level'] = 'warning'

for n in networks:
    if n['encryption'] == 'Open' and not any('Evil twin' in w for w in n['warnings']):
        n['warnings'].append('Open network')
        if n['safety_level'] == 'safe': n['safety_level'] = 'warning'

networks.sort(key=lambda x: x['signal_dbm'], reverse=True)
print(json.dumps({'success': True, 'scan_time': datetime.now().isoformat(), 'networks': networks, 'total_count': len(networks)}, indent=2))
PYTHON

exit 0
