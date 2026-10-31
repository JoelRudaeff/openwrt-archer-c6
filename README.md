# OpenWrt Archer C6: hardened Wi-Fi relay with scheduler and dashboard

Config and scripts for a TP-Link Archer C6 v2 running OpenWrt 25.12 as a **Wi-Fi access point relayed into an existing network** (`relayd`), plus a small web dashboard served by the router itself.

Personal values (Wi-Fi names, knock ports, API tokens, MAC addresses) are replaced with placeholders. Search for `<KNOCK_PORT_*>`, `ROUTER_IP`, `CAR-SSID`, `TV-SSID`, `HOME-SSID` and fill in your own.

## What is in here

| Path | What it does |
|---|---|
| `nftables.d/90-portknock.nft` | **Port knocking.** TCP 22/80/443 are dropped on every interface until a source IP sends 3 UDP packets in order. The knock expires after 1 h idle; a reverse knock closes it at once. |
| `nftables.d/05-no-ipv6.nft`, `config/99-disable-ipv6.conf` | IPv6 disabled everywhere (smaller attack surface). |
| `nftables.d/20-traffic-acct.nft`, `scripts/traffic-collect.uc` | Per-client traffic counters, collected into JSON every 5 min. |
| `config/uci-export.txt` | Relevant UCI config: dropbear (**key-only SSH, no passwords**), uhttpd (HTTPS redirect, RFC1918 filter), firewall defaults. |
| `scripts/carwifi.sh` | Cron job (every 5 min): switches the car and TV SSIDs on a weekly schedule, with a "keep on today" override. |
| `scripts/carwifi-home.sh` | Optional: asks the [Tessie](https://tessie.com) API (cached, never wakes the car) whether the car is parked at home, and keeps the Wi-Fi on while it is. |
| `scripts/uplink-watchdog.sh` | Pings the upstream router; after 3 failures runs `ifup wan`, after 6 reboots. |
| `scripts/autoupgrade.sh` | Monthly in-series firmware upgrade with `owut`. |
| `www/index.html` | Single-page dashboard: **Traffic** (per-client charts), **Car Wi-Fi** (status and override switch), **LuCI**. |
| `www/cgi-bin/carwifi`, `www/cgi-bin/traffic-data` | JSON endpoints behind the dashboard. |
| `windows/knock.ps1`, `open.bat`, `close.bat` | Windows knock client. |
| `config/crontab`, `config/sysupgrade.conf` | Cron schedule, and the keep-list so upgrades preserve the custom files. |

## Hardening summary

- Port knocking in front of SSH, HTTP and HTTPS on **all** interfaces.
- SSH: key-only, root password login disabled.
- HTTP redirects to HTTPS; `rfc1918_filter` on.
- IPv6 off, firewall `input`/`forward` default `REJECT`, SYN-flood protection.
- Uplink watchdog and monthly automatic upgrade.
- Secrets (`/etc/tessie.conf`, Wi-Fi keys, SSH keys) stay on the router and are never committed (see `config/tessie.conf.example`).

## Deploying

1. Replace the placeholders. Pick three UDP ports for the knock and put them in both `90-portknock.nft` and `windows/knock.ps1`.
2. Copy to the router. BusyBox needs the legacy protocol: `scp -O`. Keep scripts executable (`chmod 755`).

   | From | To |
   |---|---|
   | `scripts/*.sh`, `scripts/*.uc` | `/etc/` |
   | `nftables.d/*.nft` | `/etc/nftables.d/` |
   | `www/*`, `www/cgi-bin/*` | `/www/` |
   | `config/crontab` | `/etc/crontabs/root` |

3. Add the files to `/etc/sysupgrade.conf` and reload the firewall: `/etc/init.d/firewall reload`.
4. Test the knock **before** closing your session. Make a settings backup first (`sysupgrade -b`) and use an automatic rollback for risky network changes.

## Notes

- The SSID names in `carwifi.sh` match the `uci` section names `wireless.car` and `wireless.tv`.
- The schedule (off Sun–Thu 09:00–19:00, Fri–Sat 09:00–11:30) is in `carwifi.sh`; edit to taste.
- The flash is nearly full on this model: keep additions small.
