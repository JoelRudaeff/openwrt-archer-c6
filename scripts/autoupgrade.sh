#!/bin/sh
# Unattended firmware upgrade within the installed release series (e.g. 25.12.x -> newest 25.12.y).
# Never jumps to a new series (26.x): those can change config formats or outgrow the 8 MB flash.
# cron runs this on days 1-7 of each month; it only proceeds on the Tuesday, so it runs once a month
# during the car Wi-Fi off-window (10:00). owut builds a full image including relayd etc. and keeps
# all settings; a newer build of the same version (package fixes) is picked up too.
# Log: logread | grep autoupgrade
log() { logger -t autoupgrade "$*"; }
[ "$(date +%w)" = 2 ] || exit 0
cur=$(. /etc/openwrt_release; echo "$DISTRIB_RELEASE")
series=${cur%.*}
wget -q --spider https://downloads.openwrt.org/ || { log "no internet, skipping"; exit 0; }
latest=$(wget -qO- https://downloads.openwrt.org/releases/ | grep -oE "href=\"$series\.[0-9]+/" \
	| grep -oE "$series\.[0-9]+" | awk -F. '$3+0 >= m { m = $3+0; v = $0 } END { print v }')
[ -n "$latest" ] || { log "could not read release list, skipping"; exit 0; }
log "installed $cur, newest in $series series is $latest; running owut"
/etc/traffic-collect.uc flush
owut upgrade -V "$latest" 2>&1 | logger -t autoupgrade
# On success the router reboots into the new firmware and this line is never reached.
log "no upgrade performed"
