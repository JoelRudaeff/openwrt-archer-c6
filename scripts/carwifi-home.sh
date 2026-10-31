#!/bin/sh
# Is the Tesla parked at home? Asks Tessie for its cached state, so the car is never woken.
# Prints home, away or unknown, and records "<result> <epoch>" in /tmp/carwifi-home for the Car Wi-Fi page.
# /etc/carwifi.sh keeps CAR-SSID on while this says home; anything else (incl. Tessie down) -> normal schedule.
# Config /etc/tessie.conf (chmod 600), shell vars: TOKEN= VIN= HOME_LAT= HOME_LON= RADIUS=100 (metres)
# Setup: carwifi-home.sh -v  -> lists the account's VINs (no VIN set yet), else the car's position + distance.
CONF=/etc/tessie.conf
OUT=/tmp/carwifi-home
res=unknown
get() { uclient-fetch -q -T 15 -O - --header="Authorization: Bearer $TOKEN" "https://api.tessie.com/$1" 2>/dev/null; }
jf() { echo "$j" | jsonfilter -e "$1" 2>/dev/null; }
if [ -r $CONF ]; then
	. $CONF
	if [ -z "$VIN" ]; then
		[ "$1" = -v ] && { j=$(get vehicles); jf '@.results[*].vin'; }
	else
		j=$(get "$VIN/state?use_cache=true")
		lat=$(jf '@.drive_state.latitude'); lon=$(jf '@.drive_state.longitude'); gear=$(jf '@.drive_state.shift_state')
		if [ -n "$lat" ] && [ -n "$lon" ] && [ -n "$HOME_LAT" ] && [ -n "$HOME_LON" ]; then
			dist=$(awk -v a="$lat" -v b="$lon" -v c="$HOME_LAT" -v d="$HOME_LON" 'BEGIN {
				r = atan2(0, -1) / 180; x = (d - b) * r * cos((a + c) / 2 * r); y = (c - a) * r
				printf "%d", sqrt(x * x + y * y) * 6371000 }')
			# Parked = shift_state P, or none (asleep / long parked)
			if [ "$dist" -le "${RADIUS:-100}" ] && { [ -z "$gear" ] || [ "$gear" = P ]; }; then res=home; else res=away; fi
		fi
		[ "$1" = -v ] && echo "lat=$lat lon=$lon shift=${gear:-none} state=$(jf '@.state') distance=${dist:-?}m"
	fi
fi
echo "$res $(date +%s)" > $OUT
echo $res
