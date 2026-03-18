#!/bin/bash

# ════════════════════════════════════════
#  Server Health Check Script
#  Author: Rehan
#  Usage: bash health_check.sh
# ════════════════════════════════════════

# ── Configuration ────────────────────────
ALERT_EMAIL="tumhara_email@gmail.com"
ALERT_LOG="/var/log/alerts.log"
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=80
LOGFILE="/var/log/health_check.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)

# ── Colors for output ────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

# ── Logging function ─────────────────────
log() {
    local level=$1
    local message=$2
    echo "[$DATE] [$level] $message" | sudo tee -a $LOGFILE
}

# ── Print functions ───────────────────────
print_ok()      { echo -e "${GREEN}[OK]${NC}      $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_critical(){ echo -e "${RED}[CRITICAL]${NC} $1"; }

# ── Send Alert ───────────────────────────
send_alert() {
    local subject=$1
    local message=$2

    # Log mein save karo
    echo "[$DATE] ALERT: $subject — $message" | \
    sudo tee -a $ALERT_LOG

    # Mail send karo (agar mail configured hai)
    if command -v mail &>/dev/null; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
        echo "Alert email sent to $ALERT_EMAIL"
    else
        echo "⚠ Mail not configured — alert logged only"
    fi
}

# ── Check CPU ────────────────────────────
check_cpu() {
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'.' -f1)

    echo "── CPU Check ──────────────────"
    echo "   Current Usage: ${cpu_usage}%"
    echo "   Threshold:     ${CPU_THRESHOLD}%"

    if [ "$cpu_usage" -ge "$CPU_THRESHOLD" ]; then
        print_critical "CPU usage is ${cpu_usage}% (above ${CPU_THRESHOLD}%)"
        log "CRITICAL" "CPU usage: ${cpu_usage}%"
        return 1
    else
        print_ok "CPU usage is ${cpu_usage}%"
        log "OK" "CPU usage: ${cpu_usage}%"
        return 0
    fi
}

# ── Check Memory ─────────────────────────
check_memory() {
    local total used percentage
    total=$(free -m | awk 'NR==2{print $2}')
    used=$(free -m | awk 'NR==2{print $3}')
    percentage=$(awk "BEGIN{printf \"%d\", ($used/$total)*100}")

    echo ""
    echo "── Memory Check ────────────────"
    echo "   Total:   ${total}MB"
    echo "   Used:    ${used}MB"
    echo "   Usage:   ${percentage}%"
    echo "   Threshold: ${MEMORY_THRESHOLD}%"

    if [ "$percentage" -ge "$MEMORY_THRESHOLD" ]; then
        print_critical "Memory usage is ${percentage}% (above ${MEMORY_THRESHOLD}%)"
        log "CRITICAL" "Memory usage: ${percentage}%"
        return 1
    else
        print_ok "Memory usage is ${percentage}%"
        log "OK" "Memory usage: ${percentage}%"
        return 0
    fi
}

# ── Check Disk ───────────────────────────
check_disk() {
    echo ""
    echo "── Disk Check ──────────────────"

    local alert=0
    while read -r line; do
        local usage mountpoint
        usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
        mountpoint=$(echo "$line" | awk '{print $6}')

        echo "   $mountpoint → ${usage}%"

        if [ "$usage" -ge "$DISK_THRESHOLD" ]; then
            print_critical "Disk ${mountpoint} is ${usage}% full!"
            log "CRITICAL" "Disk ${mountpoint}: ${usage}%"
            alert=1
        else
            print_ok "Disk ${mountpoint} is ${usage}% used"
            log "OK" "Disk ${mountpoint}: ${usage}%"
        fi
    done < <(df -h | grep '^/dev/' | awk '{print $5, $6}' | \
             tr -d '%' | awk -v t="$DISK_THRESHOLD" '{print $1, $2}' | \
             while read usage mount; do
                 df -h | grep " $mount$"
             done)
    return $alert
}

# ── Check Services ───────────────────────
check_services() {
    local services=("ssh" "cron" "myapp")
    echo ""
    echo "── Service Check ───────────────"

    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            print_ok "$service is running"
            log "OK" "Service $service: running"
        else
            print_critical "$service is DOWN!"
            log "CRITICAL" "Service $service: DOWN"
        fi
    done
}

# ── Main ─────────────────────────────────
main() {
    echo "════════════════════════════════════"
    echo "  Health Check — $HOSTNAME"
    echo "  $DATE"
    echo "════════════════════════════════════"

    check_cpu
    check_memory
    check_disk
    check_services

    echo ""
    echo "════════════════════════════════════"
    echo "  Log saved: $LOGFILE"
    echo "════════════════════════════════════"
}

main
