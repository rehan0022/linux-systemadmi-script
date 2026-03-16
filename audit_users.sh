#!/bin/bash

echo "===== USER AUDIT REPORT ====="
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo "=============================="
echo ""

echo "--- All System Users ---"
while IFS=: read -r username _ uid gid _ homedir shell; do
    if [ "$uid" -ge 1000 ] && [ "$uid" -ne 65534 ]; then
        echo "User: $username | UID: $uid | Home: $homedir | Shell: $shell"
    fi
done < /etc/passwd

echo ""
echo "--- Sudo Users ---"
grep -Po '^sudo.+:\K.*$' /etc/group | tr ',' '\n'

echo ""
echo "--- Last Logins ---"
#lastlog | grep -v "Never logged in" | grep -v "Username"
last -n 5 | head -20
