# Travel Router Project

Raspberry Pi-based portable VPN gateway with advanced security features.

## Features

- **USB Ethernet Gateway** - Connect via USB, no WiFi from client side
- **VPN-Only Routing** - All traffic enforced through WireGuard VPN
- **Fail-Closed Firewall** - Blocks traffic if VPN fails
- **WiFi Manager** - Scan and connect with evil twin detection
- **MAC Address Privacy** - Randomize or clone MAC addresses
- **Power Management** - Web-based shutdown/reboot controls
- **Web Dashboard** - Real-time monitoring and control

## Security Features

- VPN health monitoring with automatic kill switch
- Evil twin WiFi detection
- MAC address randomization
- Fail-closed firewall architecture

## Project Structure

```
travel-router-project/
├── scripts/           # Backend scripts
│   ├── network/      # WiFi management
│   ├── security/     # Firewall, MAC manager
│   └── monitoring/   # Status, watchdog
├── web-interface/    # Flask web app
│   ├── templates/    # HTML pages
│   ├── static/       # CSS, JS, assets
│   └── app.py       # Flask application
├── config/           # Configuration files
│   ├── system/      # System configs
│   └── sudoers/     # Sudo permissions
├── systemd/          # Systemd service files
└── docs/            # Documentation
```

## Version

Current version: 1.0.0 (Base System)

## License

MIT License
