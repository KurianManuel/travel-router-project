/**
 * Navigation and Sidebar Control
 * Handles hamburger menu, sidebar toggle, and power options
 */

// DOM Elements
const hamburger = document.getElementById('hamburger');
const sidebar = document.getElementById('sidebar');
const sidebarOverlay = document.getElementById('sidebarOverlay');
const powerToggle = document.getElementById('powerToggle');
const powerOptions = document.getElementById('powerOptions');

/**
 * Toggle sidebar visibility
 */
function toggleSidebar() {
    hamburger.classList.toggle('active');
    sidebar.classList.toggle('active');
    sidebarOverlay.classList.toggle('active');
    
    // Close power options when closing sidebar
    if (!sidebar.classList.contains('active')) {
        powerOptions.classList.remove('active');
    }
}

/**
 * Toggle power options dropdown
 */
function togglePowerOptions(e) {
    if (e) e.stopPropagation();
    powerOptions.classList.toggle('active');
}

// Event Listeners
if (hamburger) {
    hamburger.addEventListener('click', toggleSidebar);
}

if (sidebarOverlay) {
    sidebarOverlay.addEventListener('click', toggleSidebar);
}

if (powerToggle) {
    powerToggle.addEventListener('click', togglePowerOptions);
}

// Close sidebar when clicking navigation links (mobile)
document.querySelectorAll('.sidebar-nav a').forEach(link => {
    link.addEventListener('click', () => {
        if (window.innerWidth < 992) {
            toggleSidebar();
        }
    });
});

// Close sidebar on ESC key
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && sidebar && sidebar.classList.contains('active')) {
        toggleSidebar();
    }
});

// Close sidebar when clicking navigation links (mobile)
document.querySelectorAll('.sidebar-nav a').forEach(link => {
    link.addEventListener('click', (e) => {
        // Don't close sidebar for # links (modals)
        if (link.getAttribute('href') === '#') {
            return; // Let the onclick handler deal with it
        }
        
        if (window.innerWidth < 992) {
            toggleSidebar();
        }
    });
});

/**
 * Power Actions
 */
function rebootSystem() {
    if (confirm('Are you sure you want to reboot the system?\n\nThe system will restart and you will need to reconnect.')) {
        fetch('/api/power/reboot', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                alert('System is rebooting...\n\nPlease wait 30-60 seconds before reconnecting.');
                toggleSidebar();
            } else {
                alert('Error: ' + (data.error || 'Unknown error'));
            }
        })
        .catch(error => {
            alert('Error: ' + error.message);
        });
    }
}

function shutdownSystem() {
    if (confirm('WARNING: Are you sure you want to shutdown the system?\n\nYou will need PHYSICAL ACCESS to power it back on.')) {
        if (confirm('This is your last chance to cancel.\n\nProceed with shutdown?')) {
            fetch('/api/power/shutdown', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' }
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    alert('System is shutting down...\n\nGoodbye!');
                    toggleSidebar();
                } else {
                    alert('Error: ' + (data.error || 'Unknown error'));
                }
            })
            .catch(error => {
                alert('Error: ' + error.message);
            });
        }
    }
}

/**
 * Active page highlighting
 */
function highlightActivePage() {
    const currentPath = window.location.pathname;
    document.querySelectorAll('.sidebar-nav a').forEach(link => {
        const href = link.getAttribute('href');
        if (href === currentPath || (currentPath === '/' && href === '/')) {
            link.classList.add('active');
        } else {
            link.classList.remove('active');
        }
    });
}

// Initialize on page load
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', highlightActivePage);
} else {
    highlightActivePage();
}
