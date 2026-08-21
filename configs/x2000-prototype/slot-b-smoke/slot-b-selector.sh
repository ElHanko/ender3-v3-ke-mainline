#!/bin/sh
set -eu

device=/dev/mmcblk0p1
label_path=/dev/disk/by-partlabel/ota
cmdline_file=/proc/cmdline
readback_device=
fixture=false

usage() {
	echo "usage: $0 [--device PATH --label-path PATH --cmdline-file PATH --readback-device PATH --fixture]" >&2
	exit 2
}

while [ "$#" -gt 0 ]; do
	case "$1" in
	--apply)
		shift
		;;
	--device)
		[ "$#" -ge 2 ] || usage
		device=$2
		shift 2
		;;
	--label-path)
		[ "$#" -ge 2 ] || usage
		label_path=$2
		shift 2
		;;
	--cmdline-file)
		[ "$#" -ge 2 ] || usage
		cmdline_file=$2
		shift 2
		;;
	--readback-device)
		[ "$#" -ge 2 ] || usage
		readback_device=$2
		shift 2
		;;
	--fixture)
		fixture=true
		shift
		;;
	*)
		usage
		;;
	esac
done

[ -n "$readback_device" ] || readback_device=$device

fail() {
	echo "SLOT_B_REVERT_REFUSED: $*" >&2
	exit 1
}

[ -r "$cmdline_file" ] || fail "cannot read command line"
grep -Eq '(^|[[:space:]])root=/dev/mmcblk0p8([[:space:]]|$)' "$cmdline_file" ||
	fail "root is not /dev/mmcblk0p8"

[ -e "$label_path" ] || fail "partlabel ota is absent"
[ -e "$device" ] || fail "p1 device is absent"
label_device=$(readlink -f "$label_path") || fail "cannot resolve partlabel ota"
real_device=$(readlink -f "$device") || fail "cannot resolve p1 device"
[ "$label_device" = "$real_device" ] || fail "partlabel ota does not resolve to p1"

if [ "$fixture" = true ]; then
	[ -f "$real_device" ] || fail "fixture p1 is not a regular file"
	[ -f "$(readlink -f "$readback_device")" ] || fail "fixture read-back is not a regular file"
else
	[ -b "$real_device" ] || fail "p1 is not a block device"
	[ "$readback_device" = "$device" ] || fail "alternate read-back is fixture-only"
fi

if command -v blockdev >/dev/null 2>&1 && [ "$fixture" = false ]; then
	size=$(blockdev --getsize64 "$real_device") || fail "cannot determine p1 size"
else
	size=$(wc -c < "$real_device") || fail "cannot determine fixture size"
fi
[ "$size" = 1048576 ] || fail "p1 size is $size, expected 1048576"

tmp=${TMPDIR:-/tmp}/slot-b-selector.$$
cleanup() {
	rm -f "$tmp.a" "$tmp.b" "$tmp.before" "$tmp.after"
}
trap cleanup EXIT HUP INT TERM

printf 'ota:kernel2\n\n' > "$tmp.b"
dd if=/dev/zero bs=1 count=499 2>/dev/null >> "$tmp.b"
printf 'ota:kernel\n\n' > "$tmp.a"
dd if=/dev/zero bs=1 count=500 2>/dev/null >> "$tmp.a"

dd if="$real_device" of="$tmp.before" bs=512 count=1 2>/dev/null || fail "cannot read p1"
cmp -s "$tmp.before" "$tmp.b" || fail "p1 is not exact ota:kernel2 with NUL padding"

dd if="$tmp.a" of="$real_device" bs=512 count=1 conv=notrunc 2>/dev/null ||
	fail "p1 write failed"
sync

readback_real=$(readlink -f "$readback_device") || fail "cannot resolve read-back device"
dd if="$readback_real" of="$tmp.after" bs=512 count=1 2>/dev/null ||
	fail "cannot read back p1"
if ! cmp -s "$tmp.after" "$tmp.a"; then
	echo 'SLOT_B_REVERT_VERIFY_FAILED: no further storage write will be attempted' >&2
	exit 1
fi

if [ "$fixture" = false ]; then
	: > /run/slot-b-next-boot-stock-a
fi
echo NEXT_BOOT_IS_STOCK_A
