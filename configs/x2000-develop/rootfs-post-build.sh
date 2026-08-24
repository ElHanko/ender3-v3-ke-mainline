#!/bin/sh
set -eu

target=$1

install -d -m 0700 "$target/root/.ssh"
ln -snf ../run/x2000-develop/resolv.conf "$target/etc/resolv.conf"
rm -f "$target/etc/wpa_supplicant.conf"

chmod 0755 \
	"$target/etc/init.d/S20x2000-develop-provision" \
	"$target/etc/init.d/S40x2000-develop-network" \
	"$target/etc/init.d/S50dropbear" \
	"$target/usr/libexec/x2000-develop-udhcpc"
