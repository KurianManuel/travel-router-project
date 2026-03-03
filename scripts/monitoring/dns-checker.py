#!/usr/bin/env python3
"""
DNS Integrity Checker
Compares local DNS results with DNS-over-HTTPS (DoH) to detect DNS spoofing
"""

import json
import socket
import time
import sys
import subprocess
from datetime import datetime

try:
    import requests
except ImportError:
    print("ERROR: requests library not installed. Run: pip3 install requests --break-system-packages")
    sys.exit(1)

# Configuration
STATE_DIR = "/run/dns-checker"
LOG_FILE = "/var/log/dns-checker.log"
KILL_SWITCH = "/usr/local/sbin/lockdown.sh"

# DNS-over-HTTPS providers (trusted)
DOH_PROVIDERS = [
    {
        "name": "Cloudflare",
        "url": "https://1.1.1.1/dns-query",
        "ip": "1.1.1.1"
    },
    {
        "name": "Google",
        "url": "https://8.8.8.8/dns-query",
        "ip": "8.8.8.8"
    }
]

# Domains to check
CHECK_DOMAINS = [
    "google.com",
    "cloudflare.com",
    "github.com",
    "amazon.com"
]

# Thresholds
MAX_IP_DISCREPANCY = 3  # Allow this many IPs to differ before triggering

def log(message, level="INFO"):
    """Write to log file"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] [{level}] {message}"
    print(log_entry)
    
    try:
        with open(LOG_FILE, "a") as f:
            f.write(log_entry + "\n")
    except:
        pass

def query_local_dns(domain):
    """Query local DNS resolver"""
    try:
        result = socket.getaddrinfo(domain, None, socket.AF_INET)
        ips = sorted(set([addr[4][0] for addr in result]))
        return ips
    except Exception as e:
        log(f"Local DNS query failed for {domain}: {e}", "ERROR")
        return None

def query_doh(domain, provider):
    """Query DNS-over-HTTPS"""
    try:
        headers = {
            "accept": "application/dns-json"
        }
        params = {
            "name": domain,
            "type": "A"
        }
        
        response = requests.get(
            provider["url"],
            headers=headers,
            params=params,
            timeout=5
        )
        
        if response.status_code == 200:
            data = response.json()
            if "Answer" in data:
                ips = sorted([answer["data"] for answer in data["Answer"] if answer["type"] == 1])
                return ips
        
        return None
        
    except Exception as e:
        log(f"DoH query failed for {domain} via {provider['name']}: {e}", "ERROR")
        return None

def compare_results(local_ips, doh_ips, domain):
    """Compare local DNS results with DoH results"""
    if local_ips is None or doh_ips is None:
        return None, "Query failed"
    
    # Convert to sets for comparison
    local_set = set(local_ips)
    doh_set = set(doh_ips)
    
    # Check for exact match
    if local_set == doh_set:
        return True, "Match"
    
    # Check for partial overlap (CDNs may return different IPs)
    overlap = local_set & doh_set
    if len(overlap) > 0:
        return True, f"Partial match ({len(overlap)} IPs in common)"
    
    # Check if both sets have IPs but no overlap
    if len(local_set) > 0 and len(doh_set) > 0:
        return False, f"No overlap - Local: {local_ips}, DoH: {doh_ips}"
    
    return None, "Inconclusive"

def trigger_kill_switch(reason):
    """Trigger system lockdown"""
    log(f"CRITICAL: Triggering kill switch - {reason}", "CRITICAL")
    
    # Save incident details
    try:
        import os
        os.makedirs(STATE_DIR, exist_ok=True)
        
        incident = {
            "timestamp": datetime.now().isoformat(),
            "reason": "DNS_SPOOFING",
            "details": reason
        }
        
        with open(f"{STATE_DIR}/incident.json", "w") as f:
            json.dump(incident, f, indent=2)
    except:
        pass
    
    # Execute kill switch
    try:
        subprocess.run([KILL_SWITCH], timeout=10)
        log("Kill switch executed", "CRITICAL")
    except Exception as e:
        log(f"Failed to execute kill switch: {e}", "ERROR")

def check_dns_integrity():
    """Perform DNS integrity check"""
    log("=== Starting DNS Integrity Check ===")
    
    mismatches = 0
    total_checks = 0
    failed_domains = []
    
    for domain in CHECK_DOMAINS:
        log(f"Checking: {domain}")
        
        # Query local DNS
        local_ips = query_local_dns(domain)
        
        if local_ips is None:
            log(f"Local DNS query failed for {domain}", "WARNING")
            continue
        
        log(f"Local DNS result: {local_ips}")
        
        # Query DoH (try multiple providers)
        doh_success = False
        for provider in DOH_PROVIDERS:
            doh_ips = query_doh(domain, provider)
            
            if doh_ips is not None:
                log(f"DoH ({provider['name']}) result: {doh_ips}")
                
                # Compare results
                match, details = compare_results(local_ips, doh_ips, domain)
                
                if match is True:
                    log(f"✓ {domain} - {details}")
                    doh_success = True
                    break
                elif match is False:
                    log(f"✗ {domain} - MISMATCH: {details}", "WARNING")
                    mismatches += 1
                    failed_domains.append({
                        "domain": domain,
                        "local": local_ips,
                        "doh": doh_ips,
                        "provider": provider['name']
                    })
                    doh_success = True
                    break
        
        if doh_success:
            total_checks += 1
        else:
            log(f"All DoH providers failed for {domain}", "ERROR")
    
    # Decision: Trigger kill switch or not
    log(f"=== Check Complete: {mismatches} mismatches out of {total_checks} checks ===")
    
    if total_checks == 0:
        log("No successful checks - cannot verify DNS integrity", "WARNING")
        return False
    
    if mismatches >= MAX_IP_DISCREPANCY:
        reason = f"DNS spoofing detected: {mismatches}/{total_checks} domains had mismatched IPs"
        for failure in failed_domains:
            reason += f"\n  {failure['domain']}: Local={failure['local']}, DoH={failure['doh']}"
        
        trigger_kill_switch(reason)
        return False
    
    log("✓ DNS integrity verified - all checks passed")
    return True

def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="DNS Integrity Checker")
    parser.add_argument('--once', action='store_true', help='Run once and exit')
    parser.add_argument('--continuous', action='store_true', help='Run continuously')
    parser.add_argument('--interval', type=int, default=300, help='Check interval in seconds (default: 300)')
    
    args = parser.parse_args()
    
    # Ensure state directory exists
    import os
    os.makedirs(STATE_DIR, exist_ok=True)
    
    if args.once:
        # Single check
        log("Running single DNS integrity check")
        success = check_dns_integrity()
        sys.exit(0 if success else 1)
    
    elif args.continuous:
        # Continuous monitoring
        log(f"Starting continuous DNS monitoring (interval: {args.interval}s)")
        
        while True:
            try:
                check_dns_integrity()
                log(f"Sleeping for {args.interval} seconds...")
                time.sleep(args.interval)
            except KeyboardInterrupt:
                log("DNS checker stopped by user")
                break
            except Exception as e:
                log(f"Error in monitoring loop: {e}", "ERROR")
                time.sleep(args.interval)
    
    else:
        # Default: single check
        log("Running single DNS integrity check (use --continuous for monitoring)")
        success = check_dns_integrity()
        sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
