#!/bin/sh
set -eu

target=$1
if [ -f "$target/etc/wpa_supplicant/wpa_supplicant.conf" ]; then
	chmod 0600 "$target/etc/wpa_supplicant/wpa_supplicant.conf"
fi
if [ -f "$target/root/.ssh/authorized_keys" ]; then
	chmod 0700 "$target/root/.ssh"
	chmod 0600 "$target/root/.ssh/authorized_keys"
fi
