#!/bin/bash

# ════════════════════════════════════════
#  Network Troubleshooting Script
#  Author: Rehan
# ════════════════════════════════════════

DATE=$(date '+%Y-%m-%d %H:%M:%S')
LOGFILE="/var/log/network_check.log"

# ── Colors ───────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── Print functions ───────────────────────
print_ok()      { echo -e "${GREEN}[OK]${NC}       $1"; }
print_warn()    { echo -e "${YELLOW}[WARN]${NC}     $1"; }
print_critical(){ echo -e "${RED}[CRITICAL]${NC} $1"; }
print_info()    { echo -e "${BLUE}[INFO]${NC}     $1"; }

log() { echo "[$DATE] $1" | sudo tee -a $LOGFILE; }

# ── Check Internet Connectivity ───────────
check_internet() {
    echo ""
    echo "── Internet Connectivity ───────────"
    local hosts=("8.8.8.8" "1.1.1.1" "google.com")

    for host in "${hosts[@]}"; do
        if ping -c 1 -W 2 "$host" &>/dev/null; then
            print_ok "Reachable: $host"
            log "OK: Internet reachable via $host"
        else
            print_critical "Unreachable: $host"
            log "CRITICAL: Cannot reach $host"
        fi
    done
}

# ── Check DNS Resolution ──────────────────
check_dns() {
    echo ""
    echo "── DNS Resolution ──────────────────"
    local domains=("google.com" "github.com" "aws.amazon.com")

    for domain in "${domains[@]}"; do
        local ip
        ip=$(dig +short "$domain" 2>/dev/null | head -1)
        if [[ -n "$ip" ]]; then
            print_ok "$domain → $ip"
            log "OK: DNS resolved $domain to $ip"
        else
            print_critical "DNS failed for $domain"
            log "CRITICAL: DNS resolution failed for $domain"
        fi
    done
}

# ── Check Open Ports ─────────────────────
check_ports() {
    echo ""
    echo "── Critical Ports ──────────────────"
    local ports=(22 80 443)

    for port in "${ports[@]}"; do
        if ss -tlnp | grep -q ":$port "; then
            local process
            process=$(ss -tlnp | grep ":$port " | \
                     awk '{print $6}' | grep -oP 'users:\(\("\K[^"]+')
            print_ok "Port $port is OPEN → $process"
            log "OK: Port $port open ($process)"
        else
            print_warn "Port $port is CLOSED"
            log "WARN: Port $port not listening"
        fi
    done
}

# ── Check Network Interfaces ─────────────
check_interfaces() {
    echo ""
    echo "── Network Interfaces ──────────────"
    while IFS= read -r line; do
        local iface ip
        iface=$(echo "$line" | awk -F': ' '{print $2}')
        ip=$(echo "$line" | awk '{print $2}' | cut -d'/' -f1)
        if [[ -n "$ip" && "$iface" != "lo" ]]; then
            print_info "$iface → $ip"
            log "INFO: Interface $iface IP $ip"
        fi
    done < <(ip -4 addr show | grep -E "inet " | \
             awk '{print $NF": "$2}')
}

# ── Check Default Gateway ─────────────────
check_gateway() {
    echo ""
    echo "── Default Gateway ─────────────────"
    local gateway
    gateway=$(ip route | grep default | awk '{print $3}' | head -1)

    if [[ -n "$gateway" ]]; then
        if ping -c 1 -W 2 "$gateway" &>/dev/null; then
            print_ok "Gateway $gateway is reachable"
            log "OK: Gateway $gateway reachable"
        else
            print_critical "Gateway $gateway is UNREACHABLE"
            log "CRITICAL: Gateway $gateway unreachable"
        fi
    else
        print_critical "No default gateway found!"
        log "CRITICAL: No default gateway"
    fi
}

# ── Check Firewall ────────────────────────
check_firewall() {
    echo ""
    echo "── Firewall Status ─────────────────"
    local ufw_status
    ufw_status=$(sudo ufw status | grep "Status:" | awk '{print $2}')

    if [[ "$ufw_status" == "active" ]]; then
        print_ok "UFW Firewall is ACTIVE"
        log "OK: UFW active"
    else
        print_critical "UFW Firewall is INACTIVE!"
        log "CRITICAL: UFW inactive — server exposed!"
    fi
}

# ── Main ──────────────────────────────────
main() {
    echo "════════════════════════════════════"
    echo "  Network Check — $(hostname)"
    echo "  $DATE"
    echo "════════════════════════════════════"

    check_interfaces
    check_gateway
    check_internet
    check_dns
    check_ports
    check_firewall

    echo ""
    echo "════════════════════════════════════"
    echo "  Log: $LOGFILE"
    echo "════════════════════════════════════"
}

main
