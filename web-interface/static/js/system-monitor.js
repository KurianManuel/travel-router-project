/**
 * system-monitor.js
 * Real-time system statistics for the System Monitor page
 * Updates CPU, memory, storage, network, and temperature metrics
 */

'use strict';

// Update interval in milliseconds
const STATS_UPDATE_INTERVAL = 3000;  // 3 seconds

/**
 * Load and display system statistics
 */
async function loadSystemStats() {
    try {
        const response = await fetch('/api/system/stats');
        const data = await response.json();
        
        if (!data.success) {
            console.error('Failed to load stats:', data.error);
            showStatsError('System monitor service not running');
            return;
        }
        
        const stats = data.stats;
        
        // Update CPU stats
        updateCPUStats(stats.cpu);
        
        // Update Memory stats
        updateMemoryStats(stats.memory);
        
        // Update Storage stats
        updateStorageStats(stats.storage);
        
        // Update Network stats
        updateNetworkStats(stats.network);
        
        // Update Temperature
        updateTemperature(stats.temperature);
        
        // Update Uptime
        updateUptime(stats.uptime);
        
        // Update WiFi Signal
        updateWiFiSignal(stats.wifi);
        
    } catch (error) {
        console.error('Error loading system stats:', error);
        showStatsError('Failed to load system statistics');
    }
}

/**
 * Update CPU statistics
 */
function updateCPUStats(cpu) {
    if (!cpu) return;
    
    const cpuPercent = cpu.percent || 0;
    
    // Update main CPU display
    const cpuUsage = document.getElementById('cpuUsage');
    if (cpuUsage) {
        cpuUsage.textContent = cpuPercent.toFixed(1) + '%';
    }
    
    // Update CPU progress bar
    const cpuBar = document.getElementById('cpuBar');
    if (cpuBar) {
        cpuBar.style.width = Math.min(cpuPercent, 100) + '%';
        
        // Set color based on usage
        cpuBar.className = 'stat-bar-fill';
        if (cpuPercent > 80) {
            cpuBar.classList.add('danger');
        } else if (cpuPercent > 60) {
            cpuBar.classList.add('warning');
        }
    }
}

/**
 * Update Memory statistics
 */
function updateMemoryStats(memory) {
    if (!memory) return;
    
    const memUsedMB = memory.used_mb || 0;
    const memTotalMB = memory.total_mb || 0;
    const memPercent = memory.percent || 0;
    const memAvailableMB = memTotalMB - memUsedMB;
    
    // Update main memory display
    const memoryUsage = document.getElementById('memoryUsage');
    if (memoryUsage) {
        memoryUsage.textContent = memUsedMB.toFixed(0) + ' MB';
    }
    
    const memoryPercent = document.getElementById('memoryPercent');
    if (memoryPercent) {
        memoryPercent.textContent = memPercent.toFixed(1) + '%';
    }
    
    // Update detailed memory stats
    const memoryTotal = document.getElementById('memoryTotal');
    if (memoryTotal) {
        memoryTotal.textContent = memTotalMB.toFixed(0) + ' MB';
    }
    
    const memoryUsedDetail = document.getElementById('memoryUsedDetail');
    if (memoryUsedDetail) {
        memoryUsedDetail.textContent = memUsedMB.toFixed(0) + ' MB';
    }
    
    const memoryAvailable = document.getElementById('memoryAvailable');
    if (memoryAvailable) {
        memoryAvailable.textContent = memAvailableMB.toFixed(0) + ' MB';
    }
    
    const memoryPercentDetail = document.getElementById('memoryPercentDetail');
    if (memoryPercentDetail) {
        memoryPercentDetail.textContent = memPercent.toFixed(1) + '%';
    }
    
    // Update memory progress bar
    const memBar = document.getElementById('memoryBar');
    if (memBar) {
        memBar.style.width = Math.min(memPercent, 100) + '%';
        
        // Set color based on usage
        memBar.className = 'stat-bar-fill';
        if (memPercent > 80) {
            memBar.classList.add('danger');
        } else if (memPercent > 60) {
            memBar.classList.add('warning');
        }
    }
}

/**
 * Update Storage statistics
 */
function updateStorageStats(storage) {
    if (!storage) return;
    
    const storageUsedGB = storage.used_gb || 0;
    const storageTotalGB = storage.total_gb || 0;
    const storageFreeGB = storageTotalGB - storageUsedGB;
    const storagePercent = storage.percent || 0;
    
    // Update main storage display
    const storageUsed = document.getElementById('storageUsed');
    if (storageUsed) {
        storageUsed.textContent = storageUsedGB.toFixed(1) + ' GB';
    }
    
    const storagePercentElem = document.getElementById('storagePercent');
    if (storagePercentElem) {
        storagePercentElem.textContent = storagePercent.toFixed(1) + '%';
    }
    
    // Update detailed storage stats
    const storageTotal = document.getElementById('storageTotal');
    if (storageTotal) {
        storageTotal.textContent = storageTotalGB.toFixed(1) + ' GB';
    }
    
    const storageUsedDetail = document.getElementById('storageUsedDetail');
    if (storageUsedDetail) {
        storageUsedDetail.textContent = storageUsedGB.toFixed(1) + ' GB';
    }
    
    const storageFreeElem = document.getElementById('storageFree');
    if (storageFreeElem) {
        storageFreeElem.textContent = storageFreeGB.toFixed(1) + ' GB';
    }
    
    const storagePercentDetail = document.getElementById('storagePercentDetail');
    if (storagePercentDetail) {
        storagePercentDetail.textContent = storagePercent.toFixed(1) + '%';
    }
}

/**
 * Update Network statistics
 */
function updateNetworkStats(network) {
    if (!network) return;
    
    // Download rate
    const netRx = document.getElementById('netRx');
    if (netRx && network.rx_kbps !== undefined) {
        netRx.textContent = network.rx_kbps.toFixed(1);
    }
    
    // Upload rate
    const netTx = document.getElementById('netTx');
    if (netTx && network.tx_kbps !== undefined) {
        netTx.textContent = network.tx_kbps.toFixed(1);
    }
    
    // Total downloaded
    const netTotalRx = document.getElementById('netTotalRx');
    if (netTotalRx && network.total_rx_mb !== undefined) {
        const totalRxMB = network.total_rx_mb;
        if (totalRxMB > 1024) {
            netTotalRx.textContent = (totalRxMB / 1024).toFixed(2) + ' GB';
        } else {
            netTotalRx.textContent = totalRxMB.toFixed(1) + ' MB';
        }
    }
    
    // Total uploaded
    const netTotalTx = document.getElementById('netTotalTx');
    if (netTotalTx && network.total_tx_mb !== undefined) {
        const totalTxMB = network.total_tx_mb;
        if (totalTxMB > 1024) {
            netTotalTx.textContent = (totalTxMB / 1024).toFixed(2) + ' GB';
        } else {
            netTotalTx.textContent = totalTxMB.toFixed(1) + ' MB';
        }
    }
}

/**
 * Update Temperature
 */
function updateTemperature(temperature) {
    if (!temperature) return;
    
    const cpuTemp = document.getElementById('cpuTemp');
    if (cpuTemp && temperature.celsius !== undefined) {
        const tempC = temperature.celsius;
        cpuTemp.textContent = tempC.toFixed(1) + '°C';
        
        // Change color based on temperature
        if (tempC > 70) {
            cpuTemp.style.color = 'var(--red)';
        } else if (tempC > 60) {
            cpuTemp.style.color = 'var(--amber)';
        } else {
            cpuTemp.style.color = 'var(--text-1)';
        }
    }
}

/**
 * Update Uptime
 */
function updateUptime(uptime) {
    if (!uptime) return;
    
    const systemUptime = document.getElementById('systemUptime');
    if (systemUptime && uptime.formatted) {
        systemUptime.textContent = uptime.formatted;
    }
}

/**
 * Update WiFi Signal
 */
function updateWiFiSignal(wifi) {
    if (!wifi) return;
    
    const wifiSignal = document.getElementById('wifiSignal');
    if (wifiSignal) {
        if (wifi.signal_dbm !== undefined && wifi.signal_dbm !== null) {
            const signalDbm = wifi.signal_dbm;
            wifiSignal.textContent = signalDbm + ' dBm';
            
            // Color code based on signal strength
            if (signalDbm > -50) {
                wifiSignal.style.color = 'var(--green)';  // Excellent
            } else if (signalDbm > -60) {
                wifiSignal.style.color = 'var(--text-1)'; // Good
            } else if (signalDbm > -70) {
                wifiSignal.style.color = 'var(--amber)';  // Fair
            } else {
                wifiSignal.style.color = 'var(--red)';    // Poor
            }
        } else {
            wifiSignal.textContent = 'Not connected';
            wifiSignal.style.color = 'var(--text-3)';
        }
    }
}

/**
 * Show error message when stats can't be loaded
 */
function showStatsError(message) {
    // Update all stat displays to show error state
    const elements = [
        'cpuUsage', 'memoryUsage', 'memoryPercent', 'storageUsed', 
        'storagePercent', 'cpuTemp', 'netRx', 'netTx', 'systemUptime', 'wifiSignal'
    ];
    
    elements.forEach(id => {
        const elem = document.getElementById(id);
        if (elem) {
            elem.textContent = '—';
        }
    });
    
    console.error('System Monitor Error:', message);
}

/**
 * Initialize the system monitor
 */
function initSystemMonitor() {
    console.log('System Monitor: Initializing...');
    
    // Load stats immediately
    loadSystemStats();
    
    // Set up automatic refresh
    setInterval(loadSystemStats, STATS_UPDATE_INTERVAL);
    
    console.log(`System Monitor: Auto-refresh every ${STATS_UPDATE_INTERVAL/1000} seconds`);
}

// Start monitoring when page loads
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initSystemMonitor);
} else {
    initSystemMonitor();
}
