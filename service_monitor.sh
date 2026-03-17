#!/bin/bash

# Services jo monitor karni hain
SERVICES=("myapp" "ssh" "cron")
LOGFILE="/var/log/service_monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "=============================" | sudo tee -a $LOGFILE
echo "Monitor Run: $DATE" | sudo tee -a $LOGFILE
echo "=============================" | sudo tee -a $LOGFILE

for service in "${SERVICES[@]}"; do
    STATUS=$(systemctl is-active "$service")

    if [ "$STATUS" == "active" ]; then
        echo "[$DATE] OK: $service is running" | sudo tee -a $LOGFILE
    else
        echo "[$DATE] WARNING: $service is DOWN - attempting restart" | sudo tee -a $LOGFILE
        sudo systemctl restart "$service"

        # Verify restart
        NEW_STATUS=$(systemctl is-active "$service")
        if [ "$NEW_STATUS" == "active" ]; then
            echo "[$DATE] RECOVERED: $service restarted successfully" | sudo tee -a $LOGFILE
        else
            echo "[$DATE] CRITICAL: $service failed to restart!" | sudo tee -a $LOGFILE
        fi
    fi
done

echo "" | sudo tee -a $LOGFILE
