#!/usr/bin/env python3
"""
Flask backend for Travel Router Web Interface
Uses gateway-status.sh script for all system data
"""

from flask import Flask, render_template, jsonify, session, request
import subprocess
import os
import re
import json
from datetime import datetime

app = Flask(__name__)
app.secret_key = os.urandom(24)

# Configuration
DEFAULT_PASSWORD = 'admin123'  # CHANGE THIS!
STATUS_SCRIPT = '/usr/local/bin/gateway-status.sh'  # Path to your status script
SCRIPT_OPEN_VPN = '/usr/local/sbin/firewall-open-vpn.sh'
SCRIPT_LOCKDOWN = '/usr/local/sbin/lockdown.sh'

class StatusParser:
    """Parse output from gateway-status.sh script"""
    
    @staticmethod
    def parse_status_output(output):
        """Extract all status information from script output"""
        data = {
            'interfaces': {},
            'ip_assignment': {},
            'wifi': {},
            'vpn': {},
            'firewall': {},
            'watchdog': {},
            'dhcp': {},
            'dhcp_clients': [],
            'management': {},
            'timestamp': datetime.now().isoformat()
        }
        
        lines = output.split('\n')
        current_section = None
        in_dhcp_clients = False
        current_client = {}
        
        for line in lines:
            line = line.strip()
            
            # Section headers
            if '[Interfaces]' in line:
                current_section = 'interfaces'
                in_dhcp_clients = False
            elif '[IP Assignment]' in line:
                current_section = 'ip_assignment'
                in_dhcp_clients = False
            elif '[Wi-Fi Association]' in line:
                current_section = 'wifi'
                in_dhcp_clients = False
            elif '[VPN Status]' in line:
                current_section = 'vpn'
                in_dhcp_clients = False
            elif '[Firewall Intent]' in line:
                current_section = 'firewall'
                in_dhcp_clients = False
            elif '[Watchdog Status]' in line:
                current_section = 'watchdog'
                in_dhcp_clients = False
            elif '[DHCP Status]' in line:
                current_section = 'dhcp'
                in_dhcp_clients = False
            elif '[Connected Clients]' in line:
                in_dhcp_clients = True
                current_client = {}
            elif '[Management Access]' in line:
                current_section = 'management'
                in_dhcp_clients = False
            
            # Parse data based on section
            if not line or line.startswith('=') or line.startswith('['):
                continue
                
            if in_dhcp_clients:
                # Parse DHCP client info - handles both bullet points and regular format
                if 'IP:' in line:
                    if current_client:  # Save previous client
                        data['dhcp_clients'].append(current_client.copy())
                    # Extract IP address after "IP:" removing any bullets or symbols
                    ip_text = line.split('IP:', 1)[1].strip()
                    current_client = {'ip': ip_text}
                elif 'MAC:' in line:
                    mac_text = line.split('MAC:', 1)[1].strip()
                    current_client['mac'] = mac_text
                elif 'Hostname:' in line:
                    hostname_text = line.split('Hostname:', 1)[1].strip()
                    current_client['hostname'] = hostname_text
                elif 'Lease expires:' in line:
                    lease_text = line.split('Lease expires:', 1)[1].strip()
                    current_client['lease_expires'] = lease_text
            
            elif current_section == 'interfaces':
                # Match lines like "wlan0 present" or "OK wlan0 present"
                if 'present' in line:
                    # Extract interface name
                    parts = line.split()
                    for part in parts:
                        if part not in ['present', 'OK', '+', '-', 'X']:
                            data['interfaces'][part] = True
                            break
                elif 'missing' in line:
                    parts = line.split()
                    for part in parts:
                        if part not in ['missing', 'OK', '+', '-', 'X']:
                            data['interfaces'][part] = False
                            break
                    
            elif current_section == 'ip_assignment':
                if 'has IPv4 address' in line:
                    # Extract interface name
                    parts = line.split()
                    for part in parts:
                        if part not in ['has', 'IPv4', 'address', 'OK', '+', '-', 'X']:
                            data['ip_assignment'][part] = True
                            break
                    
            elif current_section == 'wifi':
                if 'Connected to SSID:' in line:
                    data['wifi']['connected'] = True
                    ssid_text = line.split('SSID:', 1)[1].strip()
                    data['wifi']['ssid'] = ssid_text
                elif 'Signal:' in line:
                    signal_text = line.split('Signal:', 1)[1].strip()
                    data['wifi']['signal'] = signal_text
                elif 'Not associated' in line:
                    data['wifi']['connected'] = False
                    data['wifi']['ssid'] = 'Not connected'
                    
            elif current_section == 'vpn':
                if 'wg0 present' in line and 'no handshake' not in line:
                    data['vpn']['present'] = True
                elif 'Last handshake:' in line:
                    handshake_text = line.split('Last handshake:', 1)[1].strip()
                    data['vpn']['handshake'] = handshake_text
                elif 'Status: HEALTHY' in line:
                    data['vpn']['status'] = 'HEALTHY'
                    data['vpn']['connected'] = True
                elif 'Status: STALE' in line:
                    data['vpn']['status'] = 'STALE'
                    data['vpn']['connected'] = True
                elif 'Status: NO HANDSHAKE' in line:
                    data['vpn']['status'] = 'NO HANDSHAKE'
                    data['vpn']['connected'] = False
                elif 'Status: DOWN' in line:
                    data['vpn']['status'] = 'DOWN'
                    data['vpn']['connected'] = False
                    data['vpn']['present'] = False
                elif 'wg0 present but no handshake yet' in line:
                    data['vpn']['present'] = True
                    data['vpn']['connected'] = False
                elif 'wg0 missing' in line:
                    data['vpn']['present'] = False
                    data['vpn']['connected'] = False
                    
            elif current_section == 'firewall':
                if 'OPEN state declared' in line:
                    data['firewall']['state'] = 'OPEN'
                elif 'LOCKDOWN state' in line:
                    data['firewall']['state'] = 'LOCKDOWN'
                    
            elif current_section == 'watchdog':
                if 'Watchdog armed and running' in line:
                    data['watchdog']['armed'] = True
                    data['watchdog']['status'] = 'running'
                elif 'Watchdog not active' in line:
                    data['watchdog']['armed'] = False
                    data['watchdog']['status'] = 'not active'
                elif 'Watchdog service failed' in line:
                    data['watchdog']['armed'] = False
                    data['watchdog']['status'] = 'failed'
                    
            elif current_section == 'dhcp':
                if 'dnsmasq service running' in line:
                    data['dhcp']['service_running'] = True
                elif 'dnsmasq service not running' in line:
                    data['dhcp']['service_running'] = False
                elif 'DHCP configured on usb0' in line:
                    data['dhcp']['configured'] = True
                elif 'Range:' in line:
                    range_text = line.split('Range:', 1)[1].strip()
                    data['dhcp']['range'] = range_text
                elif 'Active DHCP leases:' in line:
                    count = re.search(r'(\d+)', line)
                    if count:
                        data['dhcp']['active_leases'] = int(count.group(1))
                elif 'No active DHCP leases' in line:
                    data['dhcp']['active_leases'] = 0
        
        # Save last client if exists
        if current_client:
            data['dhcp_clients'].append(current_client)
        
        return data

def get_system_status():
    """Run gateway-status.sh and parse output"""
    try:
        result = subprocess.run(
            [STATUS_SCRIPT],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode != 0:
            print(f"Status script returned error code: {result.returncode}")
            print(f"STDERR: {result.stderr}")
            return None
            
        parsed_data = StatusParser.parse_status_output(result.stdout)
        return parsed_data
        
    except subprocess.TimeoutExpired:
        print("ERROR: Status script timeout")
        return None
    except FileNotFoundError:
        print(f"ERROR: Status script not found at {STATUS_SCRIPT}")
        return None
    except Exception as e:
        print(f"ERROR: Exception running status script: {e}")
        return None

def get_system_uptime():
    """Get system uptime"""
    try:
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = float(f.read().split()[0])
        
        days = int(uptime_seconds // 86400)
        hours = int((uptime_seconds % 86400) // 3600)
        minutes = int((uptime_seconds % 3600) // 60)
        
        if days > 0:
            return f"{days}d {hours}h {minutes}m"
        elif hours > 0:
            return f"{hours}h {minutes}m"
        else:
            return f"{minutes}m"
    except:
        return 'Unknown'

def check_internet_connectivity():
    """Check if internet is reachable by pinging Cloudflare DNS"""
    import logging
    logger = logging.getLogger(__name__)
    
    try:
        # Ping 1.1.1.1 (Cloudflare DNS) with 2 second timeout
        result = subprocess.run(
            ['ping', '-c', '1', '-W', '2', '1.1.1.1'],
            capture_output=True,
            timeout=3,
            text=True
        )
        is_connected = result.returncode == 0
        
        if is_connected:
            logger.info("[Internet Check] Ping to 1.1.1.1: SUCCESS")
            print("[Internet Check] Ping to 1.1.1.1: SUCCESS", flush=True)
        else:
            logger.warning(f"[Internet Check] Ping to 1.1.1.1: FAILED (code: {result.returncode})")
            logger.warning(f"[Internet Check] STDERR: {result.stderr}")
            print(f"[Internet Check] Ping to 1.1.1.1: FAILED (code: {result.returncode})", flush=True)
            print(f"[Internet Check] STDERR: {result.stderr}", flush=True)
        
        return is_connected
    except subprocess.TimeoutExpired:
        logger.error("[Internet Check] Ping timeout (3s)")
        print("[Internet Check] Ping timeout (3s)", flush=True)
        return False
    except Exception as e:
        logger.error(f"[Internet Check] Exception: {e}")
        print(f"[Internet Check] Exception: {e}", flush=True)
        return False

def get_system_info():
    """Detect actual Raspberry Pi model and OS from system"""
    system_info = {
        'device': 'Raspberry Pi',
        'os': 'Linux',
        'vpn_protocol': 'WireGuard'
    }
    
    try:
        # Detect Pi model from /proc/device-tree/model
        with open('/proc/device-tree/model', 'r') as f:
            model = f.read().strip().replace('\x00', '')
            system_info['device'] = model
    except:
        try:
            # Fallback: check /proc/cpuinfo
            with open('/proc/cpuinfo', 'r') as f:
                for line in f:
                    if line.startswith('Model'):
                        system_info['device'] = line.split(':', 1)[1].strip()
                        break
        except:
            pass
    
    try:
        # Detect OS version from /etc/os-release
        with open('/etc/os-release', 'r') as f:
            for line in f:
                if line.startswith('PRETTY_NAME='):
                    os_name = line.split('=', 1)[1].strip().strip('"')
                    system_info['os'] = os_name
                    break
    except:
        pass
    
    return system_info

def get_mac_info():
    """Get current MAC address and configuration"""
    try:
        mac_info = {'current_mac': '—', 'mode': 'unknown'}
        
        try:
            with open('/sys/class/net/wlan0/address', 'r') as f:
                mac_info['current_mac'] = f.read().strip()
        except:
            pass
        
        try:
            with open('/run/mac-manager/mode', 'r') as f:
                mac_info['mode'] = f.read().strip()
        except:
            try:
                with open('/etc/mac-manager.conf', 'r') as f:
                    for line in f:
                        if line.strip().startswith('MODE='):
                            mac_info['mode'] = line.split('=')[1].strip().strip('"')
                            break
            except:
                mac_info['mode'] = 'random'
        
        return mac_info
    except:
        return {'current_mac': '—', 'mode': 'unknown'}

# Routes
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/status')
def api_status():
    """Get complete system status from gateway-status.sh"""
    status_data = get_system_status()
    
    if not status_data:
        # Fallback to basic info
        return jsonify({
            'firewall_state': 'UNKNOWN',
            'vpn_connected': False,
            'vpn_handshake': 'N/A',
            'vpn_status': 'UNKNOWN',
            'watchdog_armed': False,
            'wifi_ssid': 'Unknown',
            'uptime': get_system_uptime(),
            'pc_interface': 'usb0 (no data)',
            'vpn_tunnel': 'wg0',
            'wan_interface': 'wlan0',
            'connected_devices': 0,
            'dhcp_clients': [],
            'interfaces': {'wg0': False, 'wlan0': False, 'usb0': False},
            'internet_reachable': False,
            'error': 'Could not fetch status'
        })
    
    # Build response from parsed data
    system_info = get_system_info()
    mac_info = get_mac_info()

    response = {
        'firewall_state': status_data['firewall'].get('state', 'UNKNOWN'),
        'vpn_connected': status_data['vpn'].get('connected', False),
        'vpn_handshake': status_data['vpn'].get('handshake', 'N/A'),
        'vpn_status': status_data['vpn'].get('status', 'UNKNOWN'),
        'watchdog_armed': status_data['watchdog'].get('armed', False),
        'watchdog_status': status_data['watchdog'].get('status', 'unknown'),
        'wifi_ssid': status_data['wifi'].get('ssid', 'Not connected'),
        'wifi_signal': status_data['wifi'].get('signal', 'N/A'),
        'wifi_connected': status_data['wifi'].get('connected', False),
        'uptime': get_system_uptime(),
        'dhcp_service_running': status_data['dhcp'].get('service_running', False),
        'dhcp_configured': status_data['dhcp'].get('configured', False),
        'dhcp_range': status_data['dhcp'].get('range', 'Unknown'),
        'connected_devices': status_data['dhcp'].get('active_leases', 0),
        'dhcp_clients': status_data['dhcp_clients'],
        'interfaces': status_data['interfaces'],
        'internet_reachable': check_internet_connectivity(),
        'system_info': system_info,
        'mac_info': mac_info,
	'timestamp': status_data['timestamp']
    }
    
    # Format PC interface with DHCP client IP if available
    if status_data['dhcp_clients']:
        first_client = status_data['dhcp_clients'][0]
        response['pc_interface'] = f"usb0 ({first_client['ip']})"
        if 'hostname' in first_client:
            response['pc_hostname'] = first_client['hostname']
    else:
        response['pc_interface'] = 'usb0 (no client)'
    
    # VPN tunnel info
    if status_data['vpn'].get('connected'):
        response['vpn_tunnel'] = 'wg0 (active)'
    else:
        response['vpn_tunnel'] = 'wg0 (inactive)'
    
    # WAN interface
    response['wan_interface'] = 'wlan0'
    
    return jsonify(response)

@app.route('/api/action/open-vpn', methods=['POST'])
def action_open_vpn():
    """Execute firewall-open-vpn.sh script"""
    try:
        if not os.path.exists(SCRIPT_OPEN_VPN):
            return jsonify({
                'success': False,
                'message': 'Script not found: ' + SCRIPT_OPEN_VPN
            })
        
        result = subprocess.run(
            [SCRIPT_OPEN_VPN],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        return jsonify({
            'success': result.returncode == 0,
            'message': 'VPN-only mode activated' if result.returncode == 0 else 'Failed to activate',
            'output': result.stdout,
            'error': result.stderr
        })
        
    except subprocess.TimeoutExpired:
        return jsonify({
            'success': False,
            'message': 'Script execution timeout'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': str(e)
        })

@app.route('/api/action/lockdown', methods=['POST'])
def action_lockdown():
    """Execute lockdown.sh script"""
    try:
        if not os.path.exists(SCRIPT_LOCKDOWN):
            return jsonify({
                'success': False,
                'message': 'Script not found: ' + SCRIPT_LOCKDOWN
            })
        
        result = subprocess.run(
            [SCRIPT_LOCKDOWN],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        return jsonify({
            'success': result.returncode == 0,
            'message': 'Lockdown activated' if result.returncode == 0 else 'Failed to activate',
            'output': result.stdout,
            'error': result.stderr
        })
        
    except subprocess.TimeoutExpired:
        return jsonify({
            'success': False,
            'message': 'Script execution timeout'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': str(e)
        })

@app.route('/api/dhcp/clients')
def api_dhcp_clients():
    """Get detailed DHCP client information"""
    status_data = get_system_status()
    
    if not status_data:
        return jsonify({'clients': [], 'error': 'Could not fetch data'})
    
    return jsonify({
        'clients': status_data['dhcp_clients'],
        'total': len(status_data['dhcp_clients']),
        'service_running': status_data['dhcp'].get('service_running', False),
        'range': status_data['dhcp'].get('range', 'Unknown')
    })
@app.route('/wifi')
def wifi_manager_page():
    """WiFi manager page"""
    return render_template('wifi-manager.html')

@app.route('/api/wifi/scan', methods=['POST'])
def api_wifi_scan():
    """Scan for available WiFi networks"""
    try:
        result = subprocess.run(
            ['/usr/local/sbin/wifi-scanner.sh'],
            capture_output=True,
            text=True,
            timeout=20
        )
        
        if result.returncode != 0:
            return jsonify({'success': False, 'error': 'Scan failed'}), 500
        
        with open('/tmp/wifi-scan-results.json', 'r') as f:
            scan_data = json.load(f)
        
        return jsonify(scan_data)
        
    except subprocess.TimeoutExpired:
        return jsonify({'success': False, 'error': 'Scan timeout'}), 500
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/wifi/connect', methods=['POST'])
def api_wifi_connect():
    """Connect to a WiFi network"""
    try:
        data = request.json
        ssid = data.get('ssid')
        bssid = data.get('bssid', '')
        password = data.get('password', '')
        
        if not ssid:
            return jsonify({'success': False, 'error': 'SSID required'}), 400
        
        cmd = ['/usr/local/sbin/wifi-connect.sh', ssid]
        if bssid:
            cmd.append(bssid)
        if password:
            cmd.append(password)
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=40
        )
        
        response = json.loads(result.stdout)
        
        if response.get('success'):
            return jsonify(response)
        else:
            return jsonify(response), 500
            
    except subprocess.TimeoutExpired:
        return jsonify({'success': False, 'error': 'Connection timeout'}), 500
    except json.JSONDecodeError:
        return jsonify({'success': False, 'error': 'Invalid response'}), 500
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/wifi/current', methods=['GET'])
def api_wifi_current():
    """Get currently connected network"""
    try:
        ssid_result = subprocess.run(['iwgetid', '-r'], capture_output=True, text=True)
        ssid = ssid_result.stdout.strip() if ssid_result.returncode == 0 else None
        
        bssid = None
        link_result = subprocess.run(['iw', 'dev', 'wlan0', 'link'], capture_output=True, text=True)
        for line in link_result.stdout.split('\n'):
            if 'Connected to' in line:
                parts = line.split()
                if len(parts) >= 3:
                    bssid = parts[2]
                break
        
        return jsonify({
            'connected': ssid is not None,
            'ssid': ssid,
            'bssid': bssid
        })
    except Exception as e:
        return jsonify({'connected': False, 'error': str(e)})

@app.route('/api/power/shutdown', methods=['POST'])
def api_power_shutdown():
    """Shutdown the system"""
    try:
        subprocess.run(['sudo', 'shutdown', '-h', '+0'], capture_output=True, timeout=5)
        return jsonify({'success': True, 'message': 'System shutting down'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/power/reboot', methods=['POST'])
def api_power_reboot():
    """Reboot the system"""
    try:
        subprocess.run(['sudo', 'shutdown', '-r', '+0'], capture_output=True, timeout=5)
        return jsonify({'success': True, 'message': 'System rebooting'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# MAC Address Manager
@app.route('/api/mac/status', methods=['GET'])
def api_mac_status():
    try:
        with open('/sys/class/net/wlan0/address', 'r') as f:
            current_mac = f.read().strip()
        
        mode = "random"
        clone_mac = ""
        
        if os.path.exists('/etc/mac-manager.conf'):
            with open('/etc/mac-manager.conf', 'r') as f:
                for line in f:
                    line = line.strip()
                    if line.startswith('MODE='):
                        mode = line.split('=')[1].strip('"')
                    elif line.startswith('CLONE_MAC='):
                        clone_mac = line.split('=')[1].strip('"')
        
        mode_actual = mode
        if os.path.exists('/run/mac-manager/mode'):
            with open('/run/mac-manager/mode', 'r') as f:
                mode_actual = f.read().strip()
        
        return jsonify({
            'success': True,
            'current_mac': current_mac,
            'mode': mode,
            'mode_actual': mode_actual,
            'clone_mac': clone_mac
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/mac/configure', methods=['POST'])
def api_mac_configure():
    try:
        data = request.json
        mode = data.get('mode', 'random')
        clone_mac = data.get('clone_mac', '')
        
        if mode not in ['random', 'clone', 'persistent', 'original']:
            return jsonify({'success': False, 'error': 'Invalid mode'}), 400
        
        if mode in ['clone', 'persistent'] and clone_mac:
            if not re.match(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$', clone_mac):
                return jsonify({'success': False, 'error': 'Invalid MAC format'}), 400
        
        config_content = f'''# MAC Address Manager Configuration
MODE="{mode}"
CLONE_MAC="{clone_mac}"
'''
        
        with open('/tmp/mac-manager.conf', 'w') as f:
            f.write(config_content)
        
        result = subprocess.run(
            ['sudo', 'mv', '/tmp/mac-manager.conf', '/etc/mac-manager.conf'],
            capture_output=True, timeout=5
        )
        
        if result.returncode != 0:
            return jsonify({'success': False, 'error': 'Failed to write config'}), 500
        
        return jsonify({'success': True, 'message': 'Configuration saved. Changes apply on next reboot.'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/mac/regenerate', methods=['POST'])
def api_mac_regenerate():
    try:
        result = subprocess.run(
            ['sudo', 'systemctl', 'restart', 'mac-manager.service'],
            capture_output=True, timeout=10
        )
        
        if result.returncode != 0:
            return jsonify({'success': False, 'error': 'Failed to restart'}), 500
        
        import time
        time.sleep(2)
        
        with open('/sys/class/net/wlan0/address', 'r') as f:
            new_mac = f.read().strip()
        
        return jsonify({'success': True, 'message': 'MAC address regenerated', 'new_mac': new_mac})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

if __name__ == '__main__':
    # Check if status script exists
    if not os.path.exists(STATUS_SCRIPT):
        print(f"WARNING: Status script not found at {STATUS_SCRIPT}")
        print(f"Please update STATUS_SCRIPT path in this file")
    
    print("=" * 50)
    print("Travel Router Web Interface")
    print("=" * 50)
    print(f"Status script: {STATUS_SCRIPT}")
    print(f"Access URL: http://192.168.7.1")
    print(f"Default password: {DEFAULT_PASSWORD}")
    print("=" * 50)
    
    app.run(host='192.168.7.1', port=80, debug=False)
