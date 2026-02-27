/**
 * ui.js
 * All DOM update logic. Reads data from the API response object
 * and reflects it in the HTML. No fetch calls here.
 */

'use strict';

/**
 * Master update function.
 * Called every time a fresh status object arrives from the backend.
 * @param {Object} data - Parsed JSON from /api/status
 */
function updateUI(data) {
    console.log('[UI] Full API response:', data);
    console.log('[UI] internet_reachable value:', data.internet_reachable);
    
    updateFirewallBanner(data.firewall_state);
    updateVpnPill(data.vpn_connected);
    updateInternetPill(data.internet_reachable);
    updateVpnCell(data.vpn_status, data.vpn_handshake);
    updateWatchdogCell(data.watchdog_armed);
    updateWifiCell(data.wifi_ssid);
    updateUptimeCell(data.uptime);
    updateEnableButton(data.interfaces);
    updateNetworkDetails(data);
}

// ── Firewall state banner ─────────────────────────────────────

function updateFirewallBanner(state) {
    const banner = document.getElementById('stateBanner');
    banner.className = 'state-banner'; // reset modifiers

    const configs = {
        OPEN: {
            modifier: 'open',
            label:    'VPN-Only',
            desc:     'All traffic routed through VPN tunnel',
            badge:    'Traffic secured',
        },
        LOCKDOWN: {
            modifier: 'lockdown',
            label:    'Lockdown',
            desc:     'All internet traffic blocked (fail-closed)',
            badge:    'Internet blocked',
        },
    };

    const cfg = configs[state] || {
        modifier: 'unknown',
        label:    'Unknown',
        desc:     'Firewall state could not be determined',
        badge:    'Check system',
    };

    banner.classList.add(cfg.modifier);
    document.getElementById('firewallState').textContent = cfg.label;
    document.getElementById('firewallDesc').textContent  = cfg.desc;
    document.getElementById('stateBadge').textContent    = cfg.badge;
}

// ── VPN pill (top bar) ────────────────────────────────────────

function updateVpnPill(vpnConnected) {
    const pill = document.getElementById('vpnPill');
    const text = document.getElementById('vpnPillText');

    if (vpnConnected) {
        pill.className   = 'vpn-pill up';
        text.textContent = 'VPN Active';
    } else {
        pill.className   = 'vpn-pill down';
        text.textContent = 'VPN Down';
    }
}

// ── Internet pill (top bar) ───────────────────────────────────

function updateInternetPill(internetReachable) {
    const pill = document.getElementById('internetPill');
    const text = document.getElementById('internetPillText');

    console.log('[UI] updateInternetPill called with:', internetReachable);

    if (internetReachable) {
        pill.className   = 'vpn-pill up';
        text.textContent = 'Internet Up';
        console.log('[UI] Set internet pill to UP (green)');
    } else {
        pill.className   = 'vpn-pill down';
        text.textContent = 'Internet Down';
        console.log('[UI] Set internet pill to DOWN (red)');
    }
}

// ── Status cells ──────────────────────────────────────────────

function updateVpnCell(vpnStatus, vpnHandshake) {
    const el = document.getElementById('vpnStatus');

    const map = {
        HEALTHY: { label: 'Connected',    cls: 'stat-value green' },
        STALE:   { label: 'Stale',        cls: 'stat-value amber' },
        DOWN:    { label: 'Down',         cls: 'stat-value red'   },
    };

    const cfg = map[vpnStatus] || { label: 'No Handshake', cls: 'stat-value red' };
    el.textContent = cfg.label;
    el.className   = cfg.cls;

    document.getElementById('vpnHandshake').textContent =
        vpnHandshake ? 'Handshake ' + vpnHandshake : 'No handshake';
}

function updateWatchdogCell(armed) {
    const el  = document.getElementById('watchdogStatus');
    const sub = document.getElementById('watchdogSub');

    if (armed) {
        el.textContent  = 'Armed';
        el.className    = 'stat-value green';
        sub.textContent = 'Kill-switch active';
    } else {
        el.textContent  = 'Not Armed';
        el.className    = 'stat-value muted';
        sub.textContent = 'Kill-switch inactive';
    }
}

function updateWifiCell(ssid) {
    document.getElementById('wifiSsid').textContent = ssid || 'Not connected';
}

function updateUptimeCell(uptime) {
    document.getElementById('uptime').textContent = uptime || '—';
}

// ── Enable Internet button ────────────────────────────────────

/**
 * Disables the Enable Internet button if wg0 is absent.
 * @param {Object} interfaces - e.g. { wg0: true, wlan0: true, usb0: true }
 */
function updateEnableButton(interfaces) {
    const btn  = document.getElementById('enableBtn');
    const desc = document.getElementById('enableBtnDesc');
    const wg0Up = interfaces && interfaces['wg0'];

    if (!wg0Up) {
        btn.setAttribute('data-disabled', 'true');
        desc.textContent = 'Unavailable — wg0 is missing. Run: sudo wg-quick up wg0';
        desc.style.color = 'var(--red)';
    } else {
        btn.removeAttribute('data-disabled');
        desc.textContent = 'Opens VPN-only routing and arms the watchdog kill-switch';
        desc.style.color = '';
    }
}

// ── Network details table ─────────────────────────────────────

function updateNetworkDetails(data) {
    document.getElementById('pcInterface').textContent =
        data.pc_interface || '—';

    document.getElementById('vpnTunnel').textContent =
        data.vpn_tunnel || '—';

    document.getElementById('wanInterface').textContent =
        data.wan_interface || '—';

    document.getElementById('connectedDevices').textContent =
        data.connected_devices != null ? String(data.connected_devices) : '—';
    
    // Update system info (dynamically detected)
    if (data.system_info) {
        document.getElementById('deviceName').textContent = 
            data.system_info.device || 'Unknown';
        document.getElementById('osName').textContent = 
            data.system_info.os || 'Unknown';
        document.getElementById('vpnProtocol').textContent = 
            data.system_info.vpn_protocol || 'WireGuard';
    }
    
    // Update internet status in system info
    const internetStatusEl = document.getElementById('internetStatus');
    if (data.internet_reachable) {
        internetStatusEl.textContent = 'Connected';
        internetStatusEl.style.color = 'var(--green)';
    } else {
        internetStatusEl.textContent = 'Disconnected';
        internetStatusEl.style.color = 'var(--red)';
    }
    
    // Update MAC address info if available
    if (data.mac_info) {
        document.getElementById('macAddress').textContent = data.mac_info.current_mac || '—';
        const modeText = {
            'random': 'Random (Privacy)',
            'clone': 'Cloned',
            'persistent': 'Persistent',
            'original': 'Original'
        }[data.mac_info.mode] || data.mac_info.mode;
        document.getElementById('macModeText').textContent = modeText;
    }
}

// ── Clock ─────────────────────────────────────────────────────

function updateTime() {
    const el = document.getElementById('currentTime');
    if (el) {
        el.textContent = new Date().toLocaleTimeString('en-US', {
            hour: '2-digit', minute: '2-digit', hour12: true,
        });
    }
}
