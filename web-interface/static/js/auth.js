/**
 * auth.js
 * Handles login form, logout, and session persistence via sessionStorage.
 * Depends on: main.js (calls showDashboard / hideDashboard)
 */

'use strict';

// ── Password ──────────────────────────────────────────────────
// Change this value to set your access password.
const DEFAULT_PASSWORD = '12345';

// ── Session key ───────────────────────────────────────────────
const SESSION_KEY = 'gateway_auth';

/**
 * Returns true if the user is currently authenticated.
 */
function isAuthenticated() {
    return sessionStorage.getItem(SESSION_KEY) === 'true';
}

/**
 * Wires up the login form submit handler.
 * Called once from main.js on DOMContentLoaded.
 */
function initAuth() {
    const form = document.getElementById('loginForm');
    if (form) {
        form.addEventListener('submit', handleLogin);
    }
}

/**
 * Handles the login form submission.
 */
async function handleLogin(e) {
    e.preventDefault();
    
    const password = document.getElementById('password').value;
    const submitBtn = document.querySelector('.login-btn');
    const btnText = document.getElementById('loginBtnText');
    const spinner = document.getElementById('loginSpinner');
    
    // Show loading state
    btnText.style.display = 'none';
    spinner.style.display = 'inline-block';
    submitBtn.disabled = true;
    
    try {
        const response = await fetch('/api/login', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            credentials: 'include',  // IMPORTANT: Include cookies
            body: JSON.stringify({ password: password })
        });
        
        const data = await response.json();
        
        if (data.success) {
            // Store authentication state
            sessionStorage.setItem('authenticated', 'true');
            
            // Show dashboard
            showDashboard();
        } else {
            alert('Invalid password');
            btnText.style.display = 'inline';
            spinner.style.display = 'none';
            submitBtn.disabled = false;
        }
    } catch (error) {
        alert('Login failed: ' + error.message);
        btnText.style.display = 'inline';
        spinner.style.display = 'none';
        submitBtn.disabled = false;
    }
}

function isAuthenticated() {
    return sessionStorage.getItem('authenticated') === 'true';
}

function initAuth() {
    const loginForm = document.getElementById('loginForm');
    if (loginForm) {
        loginForm.addEventListener('submit', handleLogin);
    }
}

function logout() {
    sessionStorage.removeItem('authenticated');
    
    fetch('/api/logout', {
        method: 'POST',
        credentials: 'include'
    }).then(() => {
        location.reload();
    });
}

// ── Power menu functions ──────────────────────────────────────

function togglePowerMenu() {
    const dropdown = document.getElementById('powerDropdown');
    dropdown.classList.toggle('show');
}

// Close dropdown when clicking outside
window.addEventListener('click', function(e) {
    if (!e.target.closest('.power-menu')) {
        const dropdown = document.getElementById('powerDropdown');
        if (dropdown && dropdown.classList.contains('show')) {
            dropdown.classList.remove('show');
        }
    }
});

async function shutdownSystem() {
    const dropdown = document.getElementById('powerDropdown');
    dropdown.classList.remove('show');
    
    if (!confirm('Are you sure you want to shutdown the system?\n\nThe Pi will power off completely.')) {
        return;
    }
    
    try {
        const res = await fetch('/api/power/shutdown', { method: 'POST' });
        const data = await res.json();
        
        if (data.success) {
            alert('System is shutting down...\n\nYou can safely disconnect power after 30 seconds.');
            stopStatusPolling();
        } else {
            alert('Shutdown failed:\n\n' + data.error);
        }
    } catch (err) {
        alert('Shutdown request failed:\n\n' + err.message);
    }
}

async function rebootSystem() {
    const dropdown = document.getElementById('powerDropdown');
    dropdown.classList.remove('show');
    
    if (!confirm('Are you sure you want to reboot the system?\n\nThe Pi will restart.')) {
        return;
    }
    
    try {
        const res = await fetch('/api/power/reboot', { method: 'POST' });
        const data = await res.json();
        
        if (data.success) {
            alert('System is rebooting...\n\nThe dashboard will reconnect in about 60 seconds.');
            stopStatusPolling();
            
            // Try to reconnect after 60 seconds
            setTimeout(() => {
                window.location.reload();
            }, 60000);
        } else {
            alert('Reboot failed:\n\n' + data.error);
        }
    } catch (err) {
        alert('Reboot request failed:\n\n' + err.message);
    }
}
