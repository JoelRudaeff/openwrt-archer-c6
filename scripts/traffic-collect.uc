#!/usr/bin/ucode
// Per-client traffic accounting for https://ROUTER_IP/traffic.html
// cron runs this every 5 min: reads the nft counter sets (/etc/nftables.d/20-traffic-acct.nft),
// adds the growth since the last run to per-MAC totals and daily history.
// Written to RAM every run; to flash once a day at 03:00 and on "flush" (before reboots).
import * as fs from 'fs';

const RAM = '/tmp/traffic.json', FLASH = '/etc/traffic-totals.json', NAMES = '/etc/traffic-names.json';
const KINDS = ['out_down', 'out_up', 'in_down', 'in_up'];
const KEEP_DAYS = 62;

function load(path) {
	let s = fs.readfile(path);
	if (!s) return null;
	try { return json(s); } catch (e) { return null; }
}

function save(path, obj) {
	fs.writefile(path + '.tmp', sprintf('%J', obj));
	fs.rename(path + '.tmp', path);
}

function day(t) {
	let d = localtime(t);
	return sprintf('%04d-%02d-%02d', d.year, d.mon, d.mday);
}

let now = time();
let boot = trim(fs.readfile('/proc/sys/kernel/random/boot_id'));
let db = load(RAM) ?? load(FLASH) ?? { since: now, clients: {} };
// after a reboot the kernel counters restart from zero, so the old snapshot no longer applies
if (db.boot != boot)
	db.last = {};
db.last ??= {};
db.ipmac ??= {};

// client IP -> MAC on the car side (relayd keeps these in the ARP table)
for (let line in split(fs.readfile('/proc/net/arp') ?? '', '\n')) {
	let f = split(trim(line), /\s+/);
	if (length(f) >= 6 && f[5] == 'br-lan' && f[2] == '0x2')
		db.ipmac[f[0]] = f[3];
}

let today = day(now);
for (let kind in KINDS) {
	let p = fs.popen(`nft -j list set inet fw4 acct_${kind}`, 'r');
	let out = p ? p.read('all') : null;
	if (p) p.close();
	let set = null;
	try { set = json(out).nftables[1].set; } catch (e) {}
	let seen = {};
	for (let e in set?.elem ?? []) {
		let ip = e.elem.val, bytes = e.elem.counter.bytes;
		seen[ip] = bytes;
		let prev = db.last[kind]?.[ip] ?? 0;
		// counters also restart when the firewall reloads
		let delta = bytes >= prev ? bytes - prev : bytes;
		if (delta <= 0) continue;
		let mac = db.ipmac[ip] ?? ('ip ' + ip);
		db.clients[mac] ??= { first_seen: now, total: {}, days: {} };
		let c = db.clients[mac];
		c.ip = ip;
		c.last_seen = now;
		c.total[kind] = (c.total[kind] ?? 0) + delta;
		c.days[today] ??= {};
		c.days[today][kind] = (c.days[today][kind] ?? 0) + delta;
	}
	db.last[kind] = seen;
}

let cutoff = day(now - KEEP_DAYS * 86400);
for (let mac, c in db.clients)
	for (let d in keys(c.days))
		if (d < cutoff) delete c.days[d];

db.names = load(NAMES) ?? {};
db.updated = now;
db.boot = boot;
save(RAM, db);

let t = localtime(now);
if (ARGV[0] == 'flush' || !fs.stat(FLASH) || (t.hour == 3 && t.min < 5))
	save(FLASH, db);
