#!/bin/sh
# Self-heal the uplink (WAN cable) to the main router. cron runs this every 5 minutes.
# 3 failed checks in a row (~15 min): restart the uplink. 6 in a row (~30 min): reboot.
# Skips the first 10 minutes after boot. Counter lives in RAM, so no flash wear.
# Log: logread | grep uplink-watchdog
F=/tmp/uplink-fails
[ "$(cut -d. -f1 /proc/uptime)" -lt 600 ] && exit 0
if ping -c 3 -W 3 192.168.1.1 >/dev/null 2>&1; then rm -f $F; exit 0; fi
n=$(( $(cat $F 2>/dev/null || echo 0) + 1 )); echo $n > $F
logger -t uplink-watchdog "main router unreachable (check $n)"
[ $n -eq 3 ] && { logger -t uplink-watchdog "restarting uplink"; ifup wan; }
[ $n -ge 6 ] && { logger -t uplink-watchdog "rebooting"; /etc/traffic-collect.uc flush; sync; reboot; }
exit 0
