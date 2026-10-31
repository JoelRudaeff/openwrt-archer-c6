#!/bin/sh
# CAR-SSID schedule (local time): off Sun-Thu 09:00-19:00, Fri-Sat 09:00-11:30.
# Runs from cron every 5 min; only acts when the radio is in the wrong state.
# Override: /etc/carwifi-override holds a date (YYYY-MM-DD); on that date the Wi-Fi stays on.
# Any other date is stale and gets removed, so the schedule resumes the next day.
# Set/cleared from https://ROUTER_IP/carwifi.html (/www/cgi-bin/carwifi).
# Optional args for testing: carwifi.sh <weekday 0=Sun..6=Sat> <HHMM> -> prints schedule decision only.
OVR=/etc/carwifi-override
d=${1:-$(date +%w)}; t=${2:-$(date +%H%M)}
if [ "$d" -le 4 ]; then end=1900; else end=1130; fi
if [ "$t" -ge 900 ] && [ "$t" -lt "$end" ]; then want=off; else want=on; fi
[ -n "$1" ] && { echo "day=$d time=$t -> $want"; exit 0; }
if [ -f $OVR ]; then
	if [ "$(cat $OVR)" = "$(date +%F)" ]; then want=on; else rm -f $OVR; logger -t carwifi "override expired, schedule resumed"; fi
fi
# Car home: stays on while Tessie says the Tesla is parked at home (/etc/carwifi-home.sh). Tessie is asked
# only on the full hour during the off period; runs in between reuse that answer (/tmp/carwifi-home, < 65 min old).
# If Tessie can't be reached the answer isn't "home", so the schedule applies.
if [ "$want" = off ] && [ -x /etc/carwifi-home.sh ]; then
	if [ "$(date +%M)" = 00 ]; then car=$(/etc/carwifi-home.sh)
	else car=; read c ct 2>/dev/null < /tmp/carwifi-home && [ $(( $(date +%s) - ${ct:-0} )) -lt 3900 ] && car=$c; fi
	[ "$car" = home ] && want=on
fi
# TV-SSID (TV, 5 GHz, uci wireless.tv) follows the same on/off. radio0 is also the router's uplink to HOME-SSID
# (wwan), so only the TV-SSID interface is switched (uci disabled + wifi reload), never the radio. Done before
# the radio1 check below, in case the reload brings radio1 back up. Coming on takes ~60 s: channel 100 is DFS.
if uci -q get wireless.tv >/dev/null; then
	if [ "$(uci -q get wireless.tv.disabled)" = 1 ]; then tv=off; else tv=on; fi
	if [ "$want" != "$tv" ]; then
		if [ "$want" = on ]; then uci delete wireless.tv.disabled; else uci set wireless.tv.disabled=1; fi
		uci commit wireless; wifi reload; sleep 5
		logger -t carwifi "TV-SSID turned $want"
	fi
fi
if [ "$(ubus call network.wireless status | jsonfilter -e "@.radio1.up")" = true ]; then is=on; else is=off; fi
[ "$want" = "$is" ] && exit 0
if [ "$want" = off ]; then wifi down radio1; else wifi up radio1; fi
logger -t carwifi "CAR-SSID turned $want"
