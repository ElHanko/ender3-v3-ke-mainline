#!/bin/sh
set -eu

project=/project
work=/work
sdk="$work/sdk"
klipper="$work/klipper"
out="$project/local/phase3/x2000-develop"
sdk_url=https://github.com/Llixuma/ingenic-linux-kernel6.6-x2000-v1.0-20250221.git
sdk_commit=a98c2e1f22e4263ddd4153a4eca4db4dcfd2777b
klipper_url=https://github.com/Klipper3d/klipper.git
klipper_commit=0499b30374315f2a9f49fc12808527fc7d0f5cfa
kernel_firmware_dir="$work/develop-kernel-firmware"
wifi_overlay="$work/develop-wifi-overlay"
klipper_overlay="$work/develop-klipper-overlay"
firmware_names='brcm/brcmfmac43430-sdio.bin brcm/brcmfmac43430-sdio.txt'

prepare_buildroot() {
	patch="$project/patches/buildroot/0001-libffi-disable-host-static-exec-tramp.patch"
	if ! git -C "$sdk" apply --reverse --check "$patch" 2>/dev/null; then
		git -C "$sdk" apply --check "$patch"
		git -C "$sdk" apply "$patch"
	fi
	grep -Fxq 'HOST_LIBFFI_CONF_OPTS = --disable-exec-static-tramp' \
		"$sdk/buildroot/package/libffi/libffi.mk"
}

configure_buildroot() {
	buildroot_output=$1
	extra_overlay=${2:-}
	rootfs_overlay="$project/configs/x2000-develop/rootfs-overlay"
	[ -z "$extra_overlay" ] || rootfs_overlay="$rootfs_overlay $extra_overlay"
	sed -i "s#BR2_TOOLCHAIN_EXTERNAL_PATH=.*#BR2_TOOLCHAIN_EXTERNAL_PATH=\"$sdk/prebuilts/toolchains/mips-gcc720-glibc238\"#" "$buildroot_output/.config"
	cat "$project/configs/x2000-develop/buildroot.fragment" >> "$buildroot_output/.config"
	printf 'BR2_ROOTFS_OVERLAY="%s"\n' "$rootfs_overlay" >> "$buildroot_output/.config"
	make -C "$sdk/buildroot" O="$buildroot_output" olddefconfig
}

fetch() {
	[ -d "$sdk/.git" ] || git clone --filter=blob:none --no-checkout "$sdk_url" "$sdk"
	git -C "$sdk" sparse-checkout set kernel/kernel-6.6 buildroot prebuilts/toolchains/mips-gcc720-glibc238
	git -C "$sdk" checkout --detach "$sdk_commit"
	[ "$(git -C "$sdk" rev-parse HEAD)" = "$sdk_commit" ]
	prepare_buildroot

	[ -d "$klipper/.git" ] ||
		git clone --filter=blob:none --no-checkout "$klipper_url" "$klipper"
	[ "$(git -C "$klipper" remote get-url origin)" = "$klipper_url" ]
	git -C "$klipper" fetch origin "$klipper_commit"
	git -C "$klipper" checkout --detach "$klipper_commit"
	[ "$(git -C "$klipper" rev-parse HEAD)" = "$klipper_commit" ]

	brfetch="$work/buildroot-fetch"
	make -C "$sdk/buildroot" O="$brfetch" halley5_linux_minimal_defconfig
	configure_buildroot "$brfetch"
	make -C "$sdk/buildroot" O="$brfetch" source
}

prepare_klipper_overlay() {
	git -C "$klipper" clean -fdx
	git -C "$klipper" reset --hard "$klipper_commit"
	git -C "$klipper" checkout --detach "$klipper_commit"
	[ "$(git -C "$klipper" rev-parse HEAD)" = "$klipper_commit" ]
	git -C "$klipper" apply --check \
		"$project/patches/klipper/0004-x2000-passive-uart-opt-in.patch"
	git -C "$klipper" apply \
		"$project/patches/klipper/0004-x2000-passive-uart-opt-in.patch"
	git -C "$klipper" apply --reverse --check \
		"$project/patches/klipper/0004-x2000-passive-uart-opt-in.patch"

	rm -rf -- "$klipper_overlay"
	install -d -m 0755 \
		"$klipper_overlay/usr/share/klipper" \
		"$klipper_overlay/usr/share/fre3nder" \
		"$klipper_overlay/etc/klipper"
	rsync -a --exclude=.git/ "$klipper/" \
		"$klipper_overlay/usr/share/klipper/"
	printf '%s\n' 'v0.13.0-733-g0499b3037-fre3nder-passive-uart-v1' > \
		"$klipper_overlay/usr/share/klipper/klippy/.version"
	install -m 0644 "$project/configs/klipper-f005/printer-f005-mainline.cfg" \
		"$klipper_overlay/etc/klipper/printer.cfg"
	install -m 0644 "$project/configs/x2000-develop/f005-mcu-release.json" \
		"$klipper_overlay/usr/share/fre3nder/f005-mcu-release.json"
}

build_klipper_chelper() {
	buildroot_output=$1
	cc="$buildroot_output/host/bin/mips-linux-gnu-gcc"
	strip="$buildroot_output/host/bin/mips-linux-gnu-strip"
	chelper="$klipper_overlay/usr/share/klipper/klippy/chelper"
	[ -x "$cc" ]
	[ -x "$strip" ]
	set -- $(python3 - "$chelper/__init__.py" <<'PY'
import ast
import pathlib
import sys

tree = ast.parse(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
for node in tree.body:
    if isinstance(node, ast.Assign):
        if any(isinstance(target, ast.Name) and target.id == "SOURCE_FILES"
               for target in node.targets):
            for name in ast.literal_eval(node.value):
                print(name)
            break
else:
    raise SystemExit("Klipper chelper SOURCE_FILES not found")
PY
	)
	(
		cd "$chelper"
		"$cc" -Wall -g -O2 -shared -fPIC \
			-flto -fwhole-program -fno-use-linker-plugin \
			-o c_helper.so "$@"
		"$strip" --strip-unneeded c_helper.so
	)
	file "$chelper/c_helper.so" | grep -q 'ELF 32-bit LSB shared object, MIPS, MIPS32 rel2'
	! readelf -S "$chelper/c_helper.so" | grep -qE '\.debug(_|$)'
	readelf -h "$chelper/c_helper.so" | grep -Fq 'Class:                             ELF32'
	readelf -h "$chelper/c_helper.so" | grep -Fq 'Data:                              2'
	readelf -h "$chelper/c_helper.so" | grep -Eq 'Flags:.*nan2008, o32, mips32r2'
	readelf -A "$chelper/c_helper.so" | grep -Fq 'ISA: MIPS32r2'
	readelf -d "$chelper/c_helper.so" | grep -Fq 'Shared library: [libc.so.6]'
}

stage_byof_firmware() {
	input_dir="$project/local/phase3/wifi"
	firmware="$input_dir/brcmfmac43430-sdio.bin"
	nvram="$input_dir/brcmfmac43430-sdio.txt"

	[ -r "$firmware" ]
	[ -r "$nvram" ]
	[ "$(sha256sum "$firmware" | awk '{print $1}')" = \
		60dbb5b77b2c232e513322e0ff4350ab5dab5a9fcad0e26e80a2f089e652d720 ] || {
		echo 'BYOF WLAN firmware hash mismatch' >&2
		exit 1
	}
	[ "$(sha256sum "$nvram" | awk '{print $1}')" = \
		78fee458ab69c0a66ea462f6d6769e15b36f73582693f4dbb5a0e8e8be3cfb0a ] || {
		echo 'BYOF WLAN NVRAM hash mismatch' >&2
		exit 1
	}

	rm -rf -- "$kernel_firmware_dir" "$wifi_overlay"
	install -d -m 0700 "$kernel_firmware_dir/brcm"
	install -m 0600 "$firmware" "$kernel_firmware_dir/brcm/brcmfmac43430-sdio.bin"
	install -m 0600 "$nvram" "$kernel_firmware_dir/brcm/brcmfmac43430-sdio.txt"
	install -d -m 0755 "$wifi_overlay/lib/firmware/brcm"
	install -m 0600 "$firmware" "$wifi_overlay/lib/firmware/brcm/brcmfmac43430-sdio.bin"
	install -m 0600 "$nvram" "$wifi_overlay/lib/firmware/brcm/brcmfmac43430-sdio.txt"
}

prepare_kernel() {
	k="$sdk/kernel/kernel-6.6"
	git -C "$sdk" clean -fdx kernel/kernel-6.6
	git -C "$sdk" reset --hard "$sdk_commit"
	prepare_buildroot
	cp "$project/configs/x2000-develop/ender3-v3-ke.dts" \
		"$k/module_drivers/dts/x2000/ender3-v3-ke.dts"
	git -C "$sdk" apply --check "$project/configs/x2000-develop/ke-wlan.patch"
	git -C "$sdk" apply "$project/configs/x2000-develop/ke-wlan.patch"
	git -C "$sdk" apply --reverse --check "$project/configs/x2000-develop/ke-wlan.patch"

	if ! grep -q '^dtb-$(CONFIG_DT_ENDER3_V3_KE)' "$k/module_drivers/dts/Makefile"; then
		sed -i '/^obj-$(CONFIG_BUILTIN_DTB)/i dtb-$(CONFIG_DT_ENDER3_V3_KE) += x2000/ender3-v3-ke.dtb' "$k/module_drivers/dts/Makefile"
	fi
	if ! grep -q '^config DT_ENDER3_V3_KE$' "$k/arch/mips/xburst2/soc-x2000/Kconfig.DT"; then
		sed -i '/^endchoice$/i config DT_ENDER3_V3_KE\n\tbool "Ender-3 V3 KE"\n' "$k/arch/mips/xburst2/soc-x2000/Kconfig.DT"
	fi

	make -C "$k" ARCH=mips x2000_halley5_v30_linux_defconfig
	cat "$project/configs/x2000-develop/kernel.fragment" >> "$k/.config"
	cat >> "$k/.config" <<EOF
CONFIG_DT_ENDER3_V3_KE=y
CONFIG_EXTRA_FIRMWARE="$firmware_names"
CONFIG_EXTRA_FIRMWARE_DIR="$kernel_firmware_dir"
EOF
	make -C "$k" ARCH=mips olddefconfig

	grep -Fxq '# CONFIG_DT_HALLEY5_V30 is not set' "$k/.config"
	grep -Fxq 'CONFIG_DT_ENDER3_V3_KE=y' "$k/.config"
	grep -Fxq 'CONFIG_PREEMPT=y' "$k/.config"
	grep -Fxq '# CONFIG_PREEMPT_RT is not set' "$k/.config"
	grep -Fxq 'CONFIG_BLK_DEV_INITRD=y' "$k/.config"
	grep -Fxq 'CONFIG_INITRAMFS_SOURCE=""' "$k/.config"
	grep -Fxq 'CONFIG_DEVTMPFS=y' "$k/.config"
	grep -Fxq 'CONFIG_DEVTMPFS_MOUNT=y' "$k/.config"
	grep -Fxq 'CONFIG_BRCMFMAC=y' "$k/.config"
	grep -Fxq 'CONFIG_BRCMFMAC_SDIO=y' "$k/.config"
	grep -Fxq '# CONFIG_BCMDHD is not set' "$k/.config"
	grep -Fxq '# CONFIG_SND_ASOC_INGENIC is not set' "$k/.config"
	grep -Fxq '# CONFIG_VIDEOBUF2_DMA_CONTIG_INGENIC is not set' "$k/.config"
	grep -Fxq '# CONFIG_INGENIC_SPI is not set' "$k/.config"
	grep -Fxq '# CONFIG_INGENIC_SFC is not set' "$k/.config"
	grep -Fxq '# CONFIG_INGENIC_RSA is not set' "$k/.config"
	grep -Fxq '# CONFIG_SPINLOCK_TEST is not set' "$k/.config"
	grep -Fxq '# CONFIG_MEDIA_SUPPORT is not set' "$k/.config"
	grep -Fxq '# CONFIG_SOUND is not set' "$k/.config"
	grep -Fxq '# CONFIG_FB is not set' "$k/.config"
	grep -Fxq '# CONFIG_IIO is not set' "$k/.config"
	grep -Fxq '# CONFIG_INPUT_TOUCHSCREEN is not set' "$k/.config"
	grep -Fxq 'CONFIG_USB_STORAGE=y' "$k/.config"
	grep -Fxq 'CONFIG_MII=y' "$k/.config"
	grep -Fxq 'CONFIG_USB_NET_DRIVERS=y' "$k/.config"
	grep -Fxq 'CONFIG_USB_USBNET=y' "$k/.config"
	grep -Fxq 'CONFIG_USB_NET_AX88179_178A=y' "$k/.config"
	grep -Fxq 'CONFIG_USB_NET_CDC_NCM=y' "$k/.config"
	grep -Fxq 'CONFIG_USB_NET_CDCETHER=y' "$k/.config"
	! grep -Eq '^CONFIG_USB_LIBCOMPOSITE=y$' "$k/.config"
	grep -Fxq 'CONFIG_FAT_FS=y' "$k/.config"
	grep -Fxq 'CONFIG_VFAT_FS=y' "$k/.config"
	grep -Fxq "CONFIG_EXTRA_FIRMWARE=\"$firmware_names\"" "$k/.config"
	grep -Fxq "CONFIG_EXTRA_FIRMWARE_DIR=\"$kernel_firmware_dir\"" "$k/.config"
}

check_kernel_dtb() {
	k=$1
	dts="$k/module_drivers/dts/x2000/ender3-v3-ke.dts"
	dtb="$k/module_drivers/dts/x2000/ender3-v3-ke.dtb"
	decoded="$work/x2000-develop-kernel-only.dts"

	grep -Fq 'bootargs = "console=ttyS4,115200 root=/dev/mmcblk0p8 rootwait rootfstype=squashfs ro";' "$dts"
	grep -Fq 'ingenic,drvvbus-gpio = <&gpc 9 GPIO_ACTIVE_HIGH INGENIC_GPIO_NOBIAS>;' "$dts"
	grep -Fq 'ingenic,vbus-dete-gpio = <&gpd 17 GPIO_ACTIVE_LOW INGENIC_GPIO_NOBIAS>;' "$dts"
	awk '
		$0 == "&otg {" { in_node = 1; next }
		in_node && $0 == "};" { exit !okay }
		in_node && /status = "okay";/ { okay = 1 }
		END { exit !okay }
	' "$dts"
	awk '
		$0 == "&otg_phy {" { in_node = 1; next }
		in_node && $0 == "};" { exit !okay }
		in_node && /status = "okay";/ { okay = 1 }
		END { exit !okay }
	' "$dts"
	dtc -I dtb -O dts -o "$decoded" "$dtb"
	grep -Fq 'creality,ender-3-v3-ke' "$decoded"
	grep -Fq 'root=/dev/mmcblk0p8' "$decoded"
	grep -Fq 'wifi-bt-power' "$decoded"
	grep -Fq 'vmmc-supply' "$decoded"
	grep -Fq 'wlan-reg-on-gpios' "$decoded"
	grep -Fq 'ingenic,drvvbus-gpio' "$decoded"
	grep -Fq 'ingenic,vbus-dete-gpio' "$decoded"
	rm -f -- "$decoded"
}

check_default_initramfs() {
	k=$1
	archive="$k/usr/initramfs_data.cpio"
	[ -f "$archive" ]
	entries=$(cpio -it < "$archive" 2>/dev/null)
	[ "$(printf '%s\n' "$entries" | sed '/^$/d' | wc -l)" -eq 3 ]
	printf '%s\n' "$entries" | grep -Fxq dev
	printf '%s\n' "$entries" | grep -Fxq dev/console
	printf '%s\n' "$entries" | grep -Fxq root
	! printf '%s\n' "$entries" | grep -Eq '(^|/)init$'
	nm -C --defined-only "$k/vmlinux" | awk '{print $3}' | grep -Fxq '__initramfs_size'
}

check_rootfs() {
	brout=$1
	target="$brout/target"
	inittab="$target/etc/inittab"
	busybox_config=$(find "$brout/build" -maxdepth 2 -path '*/busybox-*/.config' -print -quit)
	dropbear_options=$(find "$brout/build" -maxdepth 2 -path '*/dropbear-*/localoptions.h' -print -quit)

	grep -Fxq 'BR2_ROOTFS_DEVICE_CREATION_DYNAMIC_MDEV=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_WPA_SUPPLICANT=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_WPA_SUPPLICANT_NL80211=y' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_WPA_SUPPLICANT_WEXT is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_WPA_SUPPLICANT_EAP is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_WPA_SUPPLICANT_DBUS is not set' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_LIBNL=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_DROPBEAR=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_DROPBEAR_SMALL=y' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_DROPBEAR_CLIENT is not set' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_DROPBEAR_LOCALOPTIONS_FILE="/project/configs/x2000-develop/dropbear.localoptions"' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON3=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON3_ZLIB=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON_CFFI=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON_GREENLET=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON_JINJA2=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON_MARKUPSAFE=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON_SERIAL=y' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_PYTHON_CAN is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_ALSA_LIB is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_ALSA_UTILS is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_OPENSSL is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_JPEG is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_EXPAT is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_NCURSES is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_READLINE is not set' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_ZLIB=y' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_MTD is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_I2C_TOOLS is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_INPUT_EVENT_DAEMON is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_SPI_TOOLS is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_SYSSTAT is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_IFUPDOWN_SCRIPTS is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_BASH is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_ANDROID_TOOLS is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_DAEMON is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_UTIL_LINUX is not set' "$brout/.config"
	grep -Fxq '# BR2_TARGET_GENERIC_REMOUNT_ROOTFS_RW is not set' "$brout/.config"
	grep -Fxq '# BR2_TARGET_ROOTFS_JFFS2 is not set' "$brout/.config"
	grep -Fxq '# BR2_TARGET_ROOTFS_UBIFS is not set' "$brout/.config"
	grep -Fxq 'BR2_TARGET_ROOTFS_SQUASHFS4_XZ=y' "$brout/.config"
	for init_script in S09x2000-develop-storage S10fre3nder-persistence \
		S10mdev S20x2000-develop-provision \
		S40x2000-develop-network S50dropbear S60fre3nder-klipper; do
		[ -x "$target/etc/init.d/$init_script" ]
	done
	[ ! -e "$target/etc/init.d/S51x2000-develop-ssh-recovery-test" ]
	[ ! -e "$target/usr/share/x2000-develop-ssh-recovery-test" ]
	printf '%s\n' \
		S09x2000-develop-storage \
		S10fre3nder-persistence \
		S20x2000-develop-provision \
		S40x2000-develop-network \
		S50dropbear \
		S60fre3nder-klipper | sort -C
	[ -n "$busybox_config" ]
	[ -n "$dropbear_options" ]
	grep -Fxq '# CONFIG_UDHCPD is not set' "$busybox_config"
	grep -Fxq 'CONFIG_UDHCPC=y' "$busybox_config"
	grep -Fxq '#define DROPBEAR_SVR_PASSWORD_AUTH 0' "$dropbear_options"
	[ -x "$target/sbin/udhcpc" ]
	[ -x "$target/sbin/blkid" ]
	[ -x "$target/bin/mount" ]
	[ -x "$target/bin/umount" ]
	[ ! -e "$target/usr/sbin/udhcpd" ]
	[ -x "$target/usr/sbin/wpa_supplicant" ]
	[ -x "$target/usr/sbin/dropbear" ]
	[ -x "$target/usr/bin/dropbearkey" ]
	[ -x "$target/usr/bin/python3" ]
	[ -x "$target/usr/libexec/fre3nder/f005-mcu-state" ]
	[ -x "$target/usr/libexec/fre3nder/f005-stock-to-fre3nder" ]
	[ -f "$target/usr/share/klipper/COPYING" ]
	[ -f "$target/usr/share/klipper/klippy/klippy.py" ]
	[ -f "$target/usr/share/klipper/klippy/chelper/c_helper.so" ]
	[ -f "$target/usr/share/fre3nder/f005-mcu-release.json" ]
	[ -f "$target/etc/klipper/printer.cfg" ]
	grep -Fxq 'x2000_passive_uart: True' "$target/etc/klipper/printer.cfg"
	service="$target/etc/init.d/S60fre3nder-klipper"
	grep -Fq 'input_tty=$runtime/printer' "$service"
	grep -Fq 'set_status starting' "$service"
	grep -Fq '"$python" "$klippy" -I "$input_tty" -l "$log_file" "$config"' "$service"
	grep -Fq 'set_status startup-failed' "$service"
	grep -Fq 'rm -f "$pid_file" "$input_tty"' "$service"
	if grep -Fq '"$python" "$klippy" "$config" -l "$log_file"' "$service"; then
		echo 'Develop RootFS contains obsolete Klippy /tmp input-TTY launch' >&2
		exit 1
	fi
	file "$target/usr/share/klipper/klippy/chelper/c_helper.so" |
		grep -q 'ELF 32-bit LSB shared object, MIPS, MIPS32 rel2'
	readelf -h "$target/usr/share/klipper/klippy/chelper/c_helper.so" |
		grep -Eq 'Flags:.*nan2008, o32, mips32r2'
	if find "$target" -type f -name mcu_util -print -quit | grep -q .; then
		echo 'Develop RootFS contains forbidden BYOF mcu_util' >&2
		exit 1
	fi
	[ ! -e "$target/init" ]
	[ -d "$target/dev/pts" ]
	[ -d "$target/root/.ssh" ] && [ ! -L "$target/root/.ssh" ]
	[ "$(readlink "$target/etc/resolv.conf")" = ../run/x2000-develop/resolv.conf ]
	mkdir_line=$(grep -nF '::sysinit:/bin/mkdir -p /dev/pts' "$inittab" | cut -d: -f1)
	mount_line=$(grep -nF '::sysinit:/bin/mount -t devpts devpts /dev/pts' "$inittab" | cut -d: -f1)
	[ "$mkdir_line" -lt "$mount_line" ]
	grep -Fq '"$mount_cmd" -t vfat -o ro,nosuid,nodev,noexec' \
		"$target/etc/init.d/S20x2000-develop-provision"
	! grep -Eq 'blkid.*TYPE|TYPE=.*vfat' \
		"$target/etc/init.d/S20x2000-develop-provision"
	grep -Fq 'usb_wait_seconds=${X2000_DEVELOP_USB_WAIT_SECONDS:-10}' \
		"$target/etc/init.d/S20x2000-develop-provision"
	grep -Fq 'multiple provisioning volumes found; refusing all' \
		"$target/etc/init.d/S20x2000-develop-provision"
	[ -d "$target/persist/system" ] && [ ! -L "$target/persist/system" ]
	[ -d "$target/persist/userdata" ] && [ ! -L "$target/persist/userdata" ]
	grep -Fq 'LABEL="FRE3NDERDATA"' \
		"$target/etc/init.d/S09x2000-develop-storage"
	grep -Fq '"$mount_cmd" -t ext4 -o rw,nosuid,nodev' \
		"$target/etc/init.d/S09x2000-develop-storage"
	grep -Fq '[ -d "$1" ] && [ ! -L "$1" ]' \
		"$target/etc/init.d/S09x2000-develop-storage"
	! grep -Eq 'mmcblk0p(9|10)' \
		"$target/etc/init.d/S09x2000-develop-storage"
	grep -Fq 'system_dir=$persist_root/system' \
		"$target/etc/init.d/S10fre3nder-persistence"
	grep -Fq 'userdata_dir=$persist_root/userdata' \
		"$target/etc/init.d/S10fre3nder-persistence"
	grep -Fq '! mounted_at "$system_dir" || ! mounted_at "$userdata_dir"' \
		"$target/etc/init.d/S10fre3nder-persistence"
	! grep -E -i -q 'x2000dev|fre3nderdata|usb|sd\[a-z\]|mmcblk0|p9|p10|rootfs_data' \
		"$target/etc/init.d/S10fre3nder-persistence"
	grep -Fq 'while [ "$seconds" -lt 30 ]' \
		"$target/etc/init.d/S40x2000-develop-network"
	grep -Fq 'Ethernet selected; DHCP lease acquired' \
		"$target/etc/init.d/S40x2000-develop-network"
	grep -Fq 'lease_file=$runtime/lease' \
		"$target/etc/init.d/S40x2000-develop-network"
	grep -Fq 'printf '\''%s\n'\'' "$interface" > "$lease_file"' \
		"$target/usr/libexec/x2000-develop-udhcpc"
	grep -Fq '"$udhcpc" -f -i "$interface"' \
		"$target/etc/init.d/S40x2000-develop-network"
	! grep -Eq 'udhcpc .*-[^ ]*b.*-[^ ]*q|udhcpc .*-[^ ]*q.*-[^ ]*b' \
		"$target/etc/init.d/S40x2000-develop-network"
	grep -Fq '[ ! -s "$provisioning/enable_ssh" ]' \
		"$target/etc/init.d/S50dropbear"
	grep -Fq 'config=$provisioning/wpa_supplicant.conf' \
		"$target/etc/init.d/S40x2000-develop-network"
	grep -Fq 'install -m 0600 "$provisioning/authorized_keys"' \
		"$target/etc/init.d/S50dropbear"
	grep -Fq '/dev/pts devpts ' "$target/etc/init.d/S50dropbear"
	grep -Fq 'dropbear_ed25519_host_key' "$target/etc/init.d/S50dropbear"
	grep -Fq 'persistence_active()' "$target/etc/init.d/S50dropbear"
	grep -Fq 'fre3nder_ssh_dir=$fre3nder_persist_root/system/fre3nder/ssh' \
		"$target/etc/init.d/S50dropbear"
	! grep -E -i -q 's09x2000|fre3nderdata|usb|sd\[a-z\]|mmcblk0|p9|p10' \
		"$target/etc/init.d/S50dropbear"
	grep -Fq '"$dropbear" -r "$hostkey" -P "$pid_file"' \
		"$target/etc/init.d/S50dropbear"
	! grep -Eq '"\$dropbear"[[:space:]]+-s([[:space:]]|$)' \
		"$target/etc/init.d/S50dropbear"
	if find "$target" -type f \( -name authorized_keys -o -name wpa_supplicant.conf -o -name 'id_*' \) -print -quit | grep -q .; then
		echo 'Develop RootFS contains credential files' >&2
		exit 1
	fi
	if find "$target" -type f -name enable_ssh -print -quit | grep -q .; then
		echo 'Develop RootFS enables SSH at build time' >&2
		exit 1
	fi
	if find "$target" -type f -name '*dropbear*host*key*' -print -quit | grep -q .; then
		echo 'Develop RootFS contains persistent Dropbear host keys' >&2
		exit 1
	fi
	if find "$target/root/.ssh" -mindepth 1 -print -quit | grep -q .; then
		echo 'Develop RootFS contains SSH state' >&2
		exit 1
	fi
	if grep -R -I -E -q -- '-----BEGIN [A-Z ]*PRIVATE KEY-----|(^|[[:space:]])psk=' \
		"$target/etc" "$target/root" 2>/dev/null; then
		echo 'Develop RootFS contains credential material' >&2
		exit 1
	fi
	if grep -R -E -i -q 'mmcblk0p(1|9|10)|ota:kernel|slot-b-selector|slot-b-revert' \
		"$target/etc/init.d" "$target/etc/inittab" "$target/etc/fstab" 2>/dev/null; then
		echo 'Develop RootFS contains selector or reserved-partition logic' >&2
		exit 1
	fi

	firmware="$target/lib/firmware/brcm/brcmfmac43430-sdio.bin"
	nvram="$target/lib/firmware/brcm/brcmfmac43430-sdio.txt"
	[ "$(sha256sum "$firmware" | awk '{print $1}')" = \
		60dbb5b77b2c232e513322e0ff4350ab5dab5a9fcad0e26e80a2f089e652d720 ]
	[ "$(sha256sum "$nvram" | awk '{print $1}')" = \
		78fee458ab69c0a66ea462f6d6769e15b36f73582693f4dbb5a0e8e8be3cfb0a ]
}

build() {
	export PATH="$sdk/prebuilts/toolchains/mips-gcc720-glibc238/bin:$PATH"
	jobs=${JOBS:-4}
	stage_byof_firmware
	prepare_kernel
	k="$sdk/kernel/kernel-6.6"
	make -C "$k" -j"$jobs" ARCH=mips CROSS_COMPILE=mips-linux-gnu- \
		HOSTCFLAGS='-Wno-error=incompatible-pointer-types' xImage dtbs
	check_default_initramfs "$k"
	[ "$(make -s -C "$k" ARCH=mips kernelrelease)" = 6.6.18-rt23 ]

	brout="$work/buildroot-output-develop"
	prepare_klipper_overlay
	extra_overlay="$wifi_overlay $klipper_overlay"
	out="$project/local/phase3/x2000-develop"
	rm -rf -- "$brout"
	make -C "$sdk/buildroot" O="$brout" halley5_linux_minimal_defconfig
	configure_buildroot "$brout" "$extra_overlay"
	make -C "$sdk/buildroot" O="$brout" -j"$jobs" toolchain
	build_klipper_chelper "$brout"
	make -C "$sdk/buildroot" O="$brout" -j"$jobs"
	check_rootfs "$brout"

	rm -rf -- "$out"
	mkdir -p "$out"
	cp "$k/arch/mips/boot/compressed/xImage" "$out/kernel.uImage"
	cp "$brout/images/rootfs.squashfs" "$out/rootfs.squashfs"
	cp "$k/module_drivers/dts/x2000/ender3-v3-ke.dtb" "$out/ender3-v3-ke.dtb"
	cp "$k/.config" "$out/effective-kernel-config"
	cp "$brout/.config" "$out/buildroot.config"

	export DEVELOP_OUTPUT="$out"
	python3 - <<'PY'
import hashlib
import json
import os
import pathlib
import subprocess

out = pathlib.Path(os.environ["DEVELOP_OUTPUT"])
artifact_names = [
    "buildroot.config",
    "effective-kernel-config",
    "ender3-v3-ke.dtb",
    "kernel.uImage",
    "rootfs.squashfs",
]
manifest = json.loads(pathlib.Path("/project/configs/x2000-develop/sources.json").read_text())
manifest["artifacts"] = {
    name: hashlib.sha256(out.joinpath(name).read_bytes()).hexdigest()
    for name in artifact_names
}
manifest["project_commit"] = subprocess.check_output(
    ["git", "-C", "/project", "rev-parse", "HEAD"], text=True
).strip()
manifest["project_worktree_status"] = (
    "clean"
    if not subprocess.check_output(
        ["git", "-C", "/project", "status", "--porcelain=v1"], text=True
    )
    else "dirty"
)
out.joinpath("build-manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n"
)
PY
	(cd "$out" && sha256sum build-manifest.json buildroot.config \
		effective-kernel-config ender3-v3-ke.dtb kernel.uImage rootfs.squashfs) \
		> "$out/SHA256SUMS"
	(cd "$out" && sha256sum -c SHA256SUMS)

	[ "$(find "$out" -maxdepth 1 -type f | wc -l)" -eq 7 ]
	file "$out/kernel.uImage" "$out/rootfs.squashfs" "$out/ender3-v3-ke.dtb"
	file "$out/rootfs.squashfs" | grep -q ', xz compressed,'
	dumpimage -l "$out/kernel.uImage"
	fdtdump "$out/ender3-v3-ke.dtb" 2>&1 | grep -E \
		'ender-3-v3-ke|root=/dev/mmcblk0p8|wifi-bt-power|wlan-reg-on-gpios'
	[ "$(stat -c '%s' "$out/kernel.uImage")" -lt 8388608 ]
	[ "$(stat -c '%s' "$out/rootfs.squashfs")" -lt 524288000 ]
	unsquashfs -ll "$out/rootfs.squashfs" | grep -q '/dev/pts$'
	! strings "$k/vmlinux" | grep -q 'ingenic,halley5'
	strings "$k/vmlinux" | grep -q 'creality,ender-3-v3-ke'
}

build_kernel_only() {
	export PATH="$sdk/prebuilts/toolchains/mips-gcc720-glibc238/bin:$PATH"
	jobs=${JOBS:-4}
	stage_byof_firmware
	prepare_kernel
	k="$sdk/kernel/kernel-6.6"
	make -C "$k" -j"$jobs" ARCH=mips CROSS_COMPILE=mips-linux-gnu- \
		HOSTCFLAGS='-Wno-error=incompatible-pointer-types' xImage dtbs
	check_default_initramfs "$k"
	[ "$(make -s -C "$k" ARCH=mips kernelrelease)" = 6.6.18-rt23 ]
	check_kernel_dtb "$k"

	out="$project/local/phase3/x2000-develop-kernel-candidate"
	rm -rf -- "$out"
	mkdir -p "$out"
	cp "$k/arch/mips/boot/compressed/xImage" "$out/kernel.uImage"
	cp "$k/module_drivers/dts/x2000/ender3-v3-ke.dtb" "$out/ender3-v3-ke.dtb"
	cp "$k/.config" "$out/effective-kernel-config"
	(cd "$out" && sha256sum kernel.uImage ender3-v3-ke.dtb effective-kernel-config) \
		> "$out/SHA256SUMS"
	(cd "$out" && sha256sum -c SHA256SUMS)

	[ "$(find "$out" -maxdepth 1 -type f | wc -l)" -eq 4 ]
	file "$out/kernel.uImage" "$out/ender3-v3-ke.dtb"
	dumpimage -l "$out/kernel.uImage"
	[ "$(stat -c '%s' "$out/kernel.uImage")" -lt 8388608 ]
	if strings "$k/vmlinux" | grep -q 'ingenic,halley5'; then
		exit 1
	fi
	strings "$k/vmlinux" | grep -q 'creality,ender-3-v3-ke'
}

build_rootfs_only() {
	stage_byof_firmware
	prepare_buildroot
	prepare_klipper_overlay
	brout="$work/buildroot-output-develop"
	make -C "$sdk/buildroot" O="$brout" halley5_linux_minimal_defconfig
	configure_buildroot "$brout" "$wifi_overlay $klipper_overlay"
	make -C "$sdk/buildroot" O="$brout" -j"${JOBS:-4}" toolchain
	build_klipper_chelper "$brout"
	make -C "$sdk/buildroot" O="$brout" rootfs-squashfs
	check_rootfs "$brout"

	out="$project/local/phase3/x2000-develop-production-candidate"
	rm -rf -- "$out"
	mkdir -p "$out"
	cp "$brout/images/rootfs.squashfs" "$out/rootfs.squashfs"
	cp "$brout/.config" "$out/buildroot.config"
	(cd "$out" && sha256sum buildroot.config rootfs.squashfs) > "$out/SHA256SUMS"
	(cd "$out" && sha256sum -c SHA256SUMS)

	[ "$(find "$out" -maxdepth 1 -type f | wc -l)" -eq 3 ]
	file "$out/rootfs.squashfs" | grep -q ', xz compressed,'
	[ "$(stat -c '%s' "$out/rootfs.squashfs")" -lt 524288000 ]
}

case "${1:-build}" in
	fetch) fetch ;;
	build) build ;;
	build-kernel-only) build_kernel_only ;;
	build-rootfs-only) build_rootfs_only ;;
	*) echo 'usage: x2000-develop {fetch|build|build-kernel-only|build-rootfs-only}' >&2; exit 2 ;;
esac
