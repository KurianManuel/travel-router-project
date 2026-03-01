# Travel Router Project

Raspberry Pi-based portable VPN gateway with advanced security features.

## Features

- **USB Ethernet Gateway** - Connect via USB, no WiFi from client side
- **VPN-Only Routing** - All traffic enforced through WireGuard VPN
- **Fail-Closed Firewall** - Blocks traffic if VPN fails
- **WiFi Manager** - Scan and connect with evil twin detection
- **MAC Address Privacy** - Randomize or clone MAC addresses
- **Power Management** - Web-based shutdown/reboot controls
- **ARP Spoofing Detection** - Real-time monitoring for man-in-the-middle attacks
- **Web Dashboard** - Real-time monitoring and control 

## Security Features

- VPN health monitoring with automatic kill switch
- Evil twin WiFi detection
- MAC address randomization
- Fail-closed firewall architecture
- ARP spoofing / man-in-the-middle attack detection
- Gateway MAC address monitoring with automatic lockdown
- Real-time security alerts on web dashboard

## Project Structure

```
travel-router-project/
├── scripts/           # Backend scripts
│   ├── network/      # WiFi management
│   ├── security/     # Firewall, MAC manager
│   └── monitoring/   # Status, watchdog, ARP monitor
├── web-interface/    # Flask web app
│   ├── templates/    # HTML pages
│   ├── static/       # CSS, JS, assets
│   └── app.py       # Flask application
├── config/           # Configuration files
│   ├── system/      # System configs
│   └── sudoers/     # Sudo permissions
└── systemd/          # Systemd service files
```

## Security Architecture

### Layered Defense

1. **Network Layer**
   - Evil twin detection during WiFi scanning
   - MAC address randomization/cloning
   - VPN-only routing enforcement

2. **ARP Layer**
   - Continuous gateway MAC monitoring
   - Baseline learning after WiFi connection
   - Automatic lockdown on MAC change detection

3. **VPN Layer**
   - WireGuard tunnel health monitoring
   - Handshake freshness verification
   - Automatic reconnection or kill switch

4. **Application Layer**
   - Real-time security alerts
   - Comprehensive logging
   - Web-based monitoring and control

## Version

Current version: 1.1.0 (ARP Spoofing Detection)

### Changelog

### v1.1.0 (2024-03-01)
- Added ARP spoofing / MITM detection system
- Real-time gateway MAC address monitoring
- Automatic kill switch on attack detection
- Web interface with live alerts and controls
- ARP Monitor page with logs and management
- Enable/disable/reset functionality
- Integration with existing security systems

#### v1.0.0 (2024-02-27)
- Initial release
- USB Ethernet gateway
- VPN-only routing with fail-closed firewall
- WiFi manager with evil twin detection
- MAC address privacy manager
- Web dashboard with real-time monitoring
- Power management controls

## License

MIT License
