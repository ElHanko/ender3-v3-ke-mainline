#!/bin/sh
set -eu

target=$1
project_root=${PROJECT_ROOT:-/project}
install -d -m 0755 "$target/usr/libexec"
install -m 0755 "$project_root/research/configs/x2000-prototype/slot-b-smoke/slot-b-selector.sh" \
	"$target/usr/libexec/slot-b-selector"
chmod 0755 "$target/etc/init.d/S00slot-b-revert" \
	"$target/etc/init.d/S01slot-b-smoke-reboot"
rm -f "$target/etc/init.d/S01seedrng" "$target/etc/init.d/S01syslogd" \
	"$target/etc/init.d/S02klogd" "$target/etc/init.d/S40network" \
	"$target/etc/init.d/S45network-provisioned" "$target/etc/init.d/S50dropbear" \
	"$target/etc/init.d/S99input-event-daemon"
