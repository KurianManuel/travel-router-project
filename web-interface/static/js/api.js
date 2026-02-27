/**
 * api.js
 * All communication with the Flask backend.
 * Functions return parsed JSON or throw on failure.
 * No DOM access — purely data layer.
 */

'use strict';

const API = {
    STATUS:   '/api/status',
    OPEN_VPN: '/api/action/open-vpn',
    LOCKDOWN: '/api/action/lockdown',
};

/**
 * Fetches the current gateway status from the backend.
 * @returns {Promise<Object>} Parsed status JSON.
 */
async function fetchStatus() {
    const res = await fetch(API.STATUS);
    if (!res.ok) throw new Error(`Status request failed: ${res.status}`);
    return res.json();
}

/**
 * Sends the Open-VPN command to the backend.
 * @returns {Promise<Object>} { success: bool, message: string }
 */
async function sendOpenVPN() {
    const res = await fetch(API.OPEN_VPN, { method: 'POST' });
    if (!res.ok) throw new Error(`Open-VPN request failed: ${res.status}`);
    return res.json();
}

/**
 * Sends the Lockdown command to the backend.
 * @returns {Promise<Object>} { success: bool, message: string }
 */
async function sendLockdown() {
    const res = await fetch(API.LOCKDOWN, { method: 'POST' });
    if (!res.ok) throw new Error(`Lockdown request failed: ${res.status}`);
    return res.json();
}
