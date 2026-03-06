/**
 * main.js
 * Application entry point.
 * Wires auth, api, and ui together.
 * Owns the status polling loop and gateway control actions.
 *
 * Load order in index.html:
 *   1. api.js
 *   2. ui.js
 *   3. auth.js
 *   4. navigation.js
 *   5. main.js   ← this file
 */

'use strict';

// ── Polling ───────────────────────────────────────────────────
const POLL_INTERVAL_MS = 5000;
let   statusInterval   = null;
let   currentStatus    = {};

/**
 * Fetches status from the backend, updates the UI.
 * Errors are logged to console but do not crash the page.
 */
async function pollStatus() {
    try {
        const data    = await fetchStatus();   // api.js
        currentStatus = data;
        updateUI(data);                        // ui.js
    } catch (err) {
        console.error('[main] Status poll failed:', err.message);
    }
}

/** Starts the polling interval and runs one immediate fetch. */
function startStatusPolling() {
    pollStatus();
    statusInterval = setInterval(pollStatus, POLL_INTERVAL_MS);
}

/** Stops the polling interval. */
function stopStatusPolling() {
    if (statusInterval) {
        clearInterval(statusInterval);
        statusInterval = null;
    }
}

// ── View transitions ──────────────────────────────────────────

/** Hides login, shows dashboard, starts polling. */
function showDashboard() {
    document.getElementById('loginScreen').style.display = 'none';
    document.getElementById('dashboard').classList.add('active');
    startStatusPolling();
    
    // Start security log polling
    startSecurityLogPolling();
    
    // Start ARP alert checking
    checkArpAlerts();
}

// ── Gateway control actions ───────────────────────────────────

/**
 * Enables VPN-only routing via the backend script.
 * Blocked in the UI if wg0 is missing, but we guard here too.
 */
async function enableInternet() {
    const wg0Up = currentStatus.interfaces && currentStatus.interfaces['wg0'];
    if (!wg0Up) {
        alert('Cannot enable: wg0 interface is missing.\n\nRun: sudo wg-quick up wg0');
        return;
    }
    if (!confirm('Enable VPN-only routing?')) return;

    try {
        const result = await sendOpenVPN();    // api.js
        if (result.success) {
            pollStatus();
        } else {
            alert('Failed to enable VPN mode:\n' + result.message);
        }
    } catch (err) {
        alert('Request failed: ' + err.message);
    }
}

/**
 * Triggers fail-closed lockdown via the backend script.
 */
async function forceLockdown() {
    if (!confirm('Trigger lockdown? This will block all internet traffic.')) return;

    try {
        const result = await sendLockdown();   // api.js
        if (result.success) {
            pollStatus();
        } else {
            alert('Failed to trigger lockdown:\n' + result.message);
        }
    } catch (err) {
        alert('Request failed: ' + err.message);
    }
}

// ── Bootstrap ─────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', () => {
    // Restore session if already logged in
    if (isAuthenticated()) {    // auth.js
        showDashboard();
    }

    // Wire up login form
    initAuth();                 // auth.js

    // Start the clock
    updateTime();               // ui.js
    setInterval(updateTime, 1000);
});

// MAC Address Configuration Functions

let currentMacConfig = {
    current_mac: '',
    mode: 'random',
    clone_mac: ''
};

async function openMacConfig() {
    try {
        // Fetch current MAC configuration
        const response = await fetch('/api/mac/status');
        const data = await response.json();
        
        if (data.success) {
            currentMacConfig = {
                current_mac: data.current_mac,
                mode: data.mode,
                clone_mac: data.clone_mac || ''
            };
            
            // Populate modal
            document.getElementById('currentMacDisplay').value = data.current_mac;
            document.getElementById('macModeSelect').value = data.mode;
            document.getElementById('cloneMacInput').value = data.clone_mac || '';
            
            updateMacFields();
            
            // Show modal
            document.getElementById('macConfigModal').classList.add('show');
        } else {
            alert('Failed to load MAC configuration: ' + data.error);
        }
    } catch (error) {
        alert('Error loading MAC configuration: ' + error.message);
    }
}

function closeMacConfig() {
    document.getElementById('macConfigModal').classList.remove('show');
}

function updateMacFields() {
    const mode = document.getElementById('macModeSelect').value;
    const cloneMacGroup = document.getElementById('cloneMacGroup');
    const regenerateBtn = document.getElementById('regenerateBtn');
    const descDiv = document.getElementById('modeDescription');
    
    // Show/hide clone MAC input
    if (mode === 'clone' || mode === 'persistent') {
        cloneMacGroup.style.display = 'block';
    } else {
        cloneMacGroup.style.display = 'none';
    }
    
    // Show regenerate button only for random mode
    if (mode === 'random') {
        regenerateBtn.style.display = 'block';
    } else {
        regenerateBtn.style.display = 'none';
    }
    
    // Update description
    const descriptions = {
        'random': '<strong>Random Mode:</strong> Generates a new random MAC address at every boot. Best for privacy - prevents tracking across WiFi networks. Each reboot gives you a "new" device identity.',
        'clone': '<strong>Clone Mode:</strong> Makes your Pi appear as another device (e.g., your phone). Useful for bypassing device limits ("only 2 devices allowed"). Enter your phone\'s MAC address below.',
        'persistent': '<strong>Persistent Mode:</strong> Uses the same fake MAC address every boot. Still hides your hardware MAC, but allows you to be recognized across sessions. Useful if a network remembers your device.',
        'original': '<strong>Original Mode:</strong> Uses your Pi\'s actual hardware MAC address. Disables MAC randomization completely. Only use if required by a specific network.'
    };
    
    descDiv.innerHTML = descriptions[mode] || '';
}

async function saveMacConfig() {
    const mode = document.getElementById('macModeSelect').value;
    let cloneMac = document.getElementById('cloneMacInput').value.trim();
    
    // Validate clone MAC if needed
    if ((mode === 'clone' || mode === 'persistent') && cloneMac) {
        const macRegex = /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/;
        if (!macRegex.test(cloneMac)) {
            alert('Invalid MAC address format. Use: aa:bb:cc:dd:ee:ff');
            return;
        }
    }
    
    // If clone/persistent but no MAC provided, ask user
    if ((mode === 'clone' || mode === 'persistent') && !cloneMac) {
        if (!confirm('No MAC address specified. Continue with empty MAC (will generate random)?')) {
            return;
        }
    }
    
    try {
        const response = await fetch('/api/mac/configure', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                mode: mode,
                clone_mac: cloneMac
            })
        });
        
        const data = await response.json();
        
        if (data.success) {
            alert('MAC configuration saved!\n\nChanges will apply on next reboot.');
            closeMacConfig();
            
            // Refresh dashboard
            setTimeout(() => {
                pollStatus();
            }, 500);
        } else {
            alert('Failed to save configuration:\n\n' + data.error);
        }
    } catch (error) {
        alert('Error saving configuration:\n\n' + error.message);
    }
}

async function regenerateMac() {
    if (!confirm('Regenerate MAC address now?\n\nThis will briefly disconnect WiFi and restart the MAC manager service.')) {
        return;
    }
    
    try {
        const response = await fetch('/api/mac/regenerate', {
            method: 'POST'
        });
        
        const data = await response.json();
        
        if (data.success) {
            alert('MAC address regenerated!\n\nNew MAC: ' + data.new_mac);
            
            // Update display
            document.getElementById('currentMacDisplay').value = data.new_mac;
            closeMacConfig();
            
            // Refresh dashboard
            setTimeout(() => {
                pollStatus();
            }, 1000);
        } else {
            alert('Failed to regenerate MAC:\n\n' + data.error);
        }
    } catch (error) {
        alert('Error regenerating MAC:\n\n' + error.message);
    }
}

// Close modal when clicking outside
document.addEventListener('click', function(e) {
    const modal = document.getElementById('macConfigModal');
    if (e.target === modal) {
        closeMacConfig();
    }
});

// ARP Monitor Alert System

let lastAlertCheck = 0;

async function checkArpAlerts() {
    try {
        const response = await fetch('/api/arp/status');
        const data = await response.json();
        
        if (data.success && data.status) {
            const status = data.status;
            
            // Check if gateway MAC has changed (mismatch)
            if (status.learned_mac && status.current_gateway_mac && 
                status.learned_mac.toLowerCase() !== status.current_gateway_mac.toLowerCase()) {
                
                // Show alert if we haven't shown it recently
                const now = Date.now();
                if (now - lastAlertCheck > 60000) {  // Once per minute max
                    showAlert(
                        'ARP Spoofing Detected!',
                        `Gateway MAC changed from ${status.learned_mac} to ${status.current_gateway_mac}. System may be locked down.`
                    );
                    lastAlertCheck = now;
                }
            }
        }
    } catch (error) {
        console.error('Failed to check ARP alerts:', error);
    }
}

function showAlert(title, message) {
    const alertNotification = document.getElementById('alertNotification');
    if (!alertNotification) return;
    
    document.getElementById('alertTitle').textContent = title;
    document.getElementById('alertMessage').textContent = message;
    alertNotification.classList.add('show');
    
    // Auto-dismiss after 30 seconds
    setTimeout(() => {
        closeAlert();
    }, 30000);
}

function closeAlert() {
    const alertNotification = document.getElementById('alertNotification');
    if (alertNotification) {
        alertNotification.classList.remove('show');
    }
}

// Check for ARP alerts every 10 seconds (only if on dashboard)
setInterval(() => {
    if (document.getElementById('dashboard') && 
        document.getElementById('dashboard').classList.contains('active')) {
        checkArpAlerts();
    }
}, 10000);

// ═══════════════════════════════════════════════════════════
// Security Log Functions
// ═══════════════════════════════════════════════════════════

/**
 * Load and display security logs
 */
function loadSecurityLogs() {
    const container = document.getElementById('securityLogContainer');
    if (!container) return; // Not on dashboard page
    
    fetch('/api/security/logs', {
        credentials: 'include'  // IMPORTANT: Include session cookie
    })
        .then(response => {
            if (response.status === 401) {
                // Not authenticated - redirect to login
                console.log('Not authenticated, reloading page');
                location.reload();
                return null;
            }
            return response.json();
        })
        .then(data => {
            if (!data) return; // Null from 401 response
            
            if (!data.success) {
                container.innerHTML = '<div class="log-empty">Error loading logs: ' + (data.error || 'Unknown error') + '</div>';
                return;
            }
            
            if (!data.logs || data.logs.length === 0) {
                container.innerHTML = '<div class="log-empty">No security events recorded</div>';
                return;
            }
            
            let html = '';
            data.logs.forEach(log => {
                const severityClass = log.severity || 'info';
                const timestamp = log.timestamp || '';
                const source = log.source || 'System';
                const message = formatLogMessage(log.log);
                
                html += `
                    <div class="log-entry ${severityClass}">
                        <div class="log-timestamp">${timestamp}</div>
                        <div class="log-source">${source}</div>
                        <div class="log-message">${message}</div>
                    </div>
                `;
            });
            
            container.innerHTML = html;
        })
        .catch(error => {
            console.error('Error loading security logs:', error);
            if (container) {
                container.innerHTML = '<div class="log-empty">Failed to load security logs</div>';
            }
        });
}

/**
 * Format log message for display
 */
function formatLogMessage(log) {
    // Remove timestamp and source prefix if present
    let message = log;
    
    // Remove common log prefixes
    message = message.replace(/^\[.*?\]\s*/, '');  // Remove [timestamp]
    message = message.replace(/^.*?:\s*/, '');      // Remove "source: "
    
    // Highlight important keywords
    message = message.replace(/(lockdown|attack|spoofing|mismatch|failed|critical)/gi, 
        '<strong style="color: var(--red);">$1</strong>');
    message = message.replace(/(triggered|detected|warning)/gi, 
        '<strong style="color: var(--amber);">$1</strong>');
    message = message.replace(/(success|passed|verified)/gi, 
        '<strong style="color: var(--green);">$1</strong>');
    
    return message;
}

/**
 * Refresh security log manually
 */
function refreshSecurityLog() {
    const container = document.getElementById('securityLogContainer');
    if (!container) return;
    
    container.innerHTML = '<div style="padding: 20px; text-align: center; color: var(--text-3);">Refreshing...</div>';
    loadSecurityLogs();
}

// ═══════════════════════════════════════════════════════════
// Auto-refresh Security Logs (only when authenticated)
// ═══════════════════════════════════════════════════════════

let securityLogInterval = null;

/**
 * Start security log polling
 */
function startSecurityLogPolling() {
    // Load immediately
    if (document.getElementById('securityLogContainer')) {
        loadSecurityLogs();
    }
    
    // Set up interval
    if (securityLogInterval) {
        clearInterval(securityLogInterval);
    }
    
    securityLogInterval = setInterval(() => {
        if (document.getElementById('securityLogContainer')) {
            loadSecurityLogs();
        }
    }, 10000); // Every 10 seconds
}

/**
 * Stop security log polling
 */
function stopSecurityLogPolling() {
    if (securityLogInterval) {
        clearInterval(securityLogInterval);
        securityLogInterval = null;
    }
}
