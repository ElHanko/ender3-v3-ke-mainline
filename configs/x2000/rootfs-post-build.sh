#!/bin/sh
set -eu

target=$1

install -d -m 0700 "$target/root/.ssh"
ln -snf ../run/fre3nder/resolv.conf "$target/etc/resolv.conf"
rm -f "$target/etc/wpa_supplicant.conf"

chmod 0755 \
	"$target/etc/init.d/S20fre3nder-provision" \
	"$target/etc/init.d/S40fre3nder-network" \
	"$target/etc/init.d/S50dropbear" \
	"$target/etc/init.d/S60fre3nder-klipper" \
	"$target/usr/libexec/fre3nder/f005-mcu-state" \
	"$target/usr/libexec/fre3nder/f005-stock-to-fre3nder" \
	"$target/usr/libexec/fre3nder-udhcpc"
