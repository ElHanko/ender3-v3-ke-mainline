#!/bin/sh
set -eu

project=/project
work=/work
version_file="$project/VERSION"
[ -f "$version_file" ] || {
	echo 'VERSION is missing' >&2
	exit 1
}
version=$(cat "$version_file")
if [ "$(wc -l < "$version_file")" -ne 1 ] ||
	! printf '%s\n' "$version" | cmp -s - "$version_file" ||
	! printf '%s\n' "$version" |
		grep -Eq '^[1-9][0-9]{3}\.[1-9][0-9]*(\.(a|b|rc))?$'; then
	echo 'VERSION must use YEAR.RELEASE[.a|.b|.rc] with a final newline' >&2
	exit 1
fi
release_year=${version%%.*}
version_tail=${version#*.}
release_number=${version_tail%%.*}
case "$version_tail" in
*.a) release_stage=alpha ;;
*.b) release_stage=beta ;;
*.rc) release_stage=rc ;;
*) release_stage=final ;;
esac
release_scope=usable-system
sdk="$work/sdk"
buildroot="$work/buildroot"
buildroot_dl="$work/buildroot-dl"
klipper="$work/klipper"
local_root="$project/local/production"
artifact_root="$local_root/artifacts/x2000"
full_out="$artifact_root/full"
kernel_out="$artifact_root/kernel-only"
rootfs_out="$artifact_root/rootfs-only"
sdk_url=https://github.com/Llixuma/ingenic-linux-kernel6.6-x2000-v1.0-20250221.git
sdk_commit=a98c2e1f22e4263ddd4153a4eca4db4dcfd2777b
buildroot_url=https://gitlab.com/buildroot.org/buildroot.git
buildroot_version=2025.02.17
buildroot_commit=d0820dd09916edcefc44e525355afbea30d5bee4
klipper_url=https://github.com/Klipper3d/klipper.git
klipper_commit=0499b30374315f2a9f49fc12808527fc7d0f5cfa
kernel_firmware_dir="$work/fre3nder-kernel-firmware"
wifi_overlay="$work/fre3nder-wifi-overlay"
klipper_overlay="$work/fre3nder-klipper-overlay"
firmware_names='brcm/brcmfmac43430-sdio.bin brcm/brcmfmac43430-sdio.txt'

prepare_buildroot() {
	[ -d "$buildroot/.git" ]
	[ "$(git -C "$buildroot" remote get-url origin)" = "$buildroot_url" ]
	git -C "$buildroot" reset --hard "$buildroot_commit"
	git -C "$buildroot" clean -fdx
	git -C "$buildroot" checkout --detach "$buildroot_commit"
	[ "$(git -C "$buildroot" rev-parse HEAD)" = "$buildroot_commit" ]
	git -C "$buildroot" diff --check
	grep -Fxq 'config BR2_mips_xburst' "$buildroot/arch/Config.in.mips"
	grep -Fq 'select BR2_MIPS_CPU_MIPS32R2' "$buildroot/arch/Config.in.mips"
	grep -Eq '^[[:space:]]*default "mips32r2"[[:space:]]+if BR2_mips_xburst$' \
		"$buildroot/arch/Config.in.mips"
	grep -Fxq 'ifeq ($(BR2_mips_xburst),y)' \
		"$buildroot/toolchain/toolchain-wrapper.mk"
	grep -Fxq 'TOOLCHAIN_WRAPPER_ARGS += -DBR_FP_CONTRACT_OFF' \
		"$buildroot/toolchain/toolchain-wrapper.mk"
	grep -Fq '"-ffp-contract=off",' \
		"$buildroot/toolchain/toolchain-wrapper.c"
	grep -Fxq 'PYTHON_GREENLET_VERSION = 3.1.1' \
		"$buildroot/package/python-greenlet/python-greenlet.mk"
}

configure_buildroot() {
	buildroot_output=$1
	extra_overlay=${2:-}
	rootfs_overlay="$project/configs/x2000/rootfs-overlay"
	[ -z "$extra_overlay" ] || rootfs_overlay="$rootfs_overlay $extra_overlay"
	rm -rf -- "$buildroot_output"
	make -C "$buildroot" O="$buildroot_output" \
		BR2_DEFCONFIG="$project/configs/x2000/buildroot.defconfig" defconfig
	cat "$project/configs/x2000/buildroot.fragment" >> "$buildroot_output/.config"
	cat >> "$buildroot_output/.config" <<EOF
BR2_DL_DIR="$buildroot_dl"
BR2_GLOBAL_PATCH_DIR="$project/patches"
BR2_ROOTFS_OVERLAY="$rootfs_overlay"
EOF
	make -C "$buildroot" O="$buildroot_output" olddefconfig
	grep -Fxq 'BR2_mipsel=y' "$buildroot_output/.config"
	grep -Fxq 'BR2_mips_xburst=y' "$buildroot_output/.config"
	grep -Fxq 'BR2_MIPS_CPU_MIPS32R2=y' "$buildroot_output/.config"
	grep -Fxq '# BR2_MIPS_SOFT_FLOAT is not set' "$buildroot_output/.config"
	grep -Fxq 'BR2_MIPS_FP32_MODE_XX=y' "$buildroot_output/.config"
	grep -Fxq 'BR2_MIPS_NAN_LEGACY=y' "$buildroot_output/.config"
	grep -Fxq 'BR2_MIPS_OABI32=y' "$buildroot_output/.config"
	grep -Fxq 'BR2_GCC_TARGET_ARCH="mips32r2"' "$buildroot_output/.config"
	grep -Fxq 'BR2_GCC_TARGET_ABI="32"' "$buildroot_output/.config"
	grep -Fxq 'BR2_GCC_TARGET_FP32_MODE="xx"' "$buildroot_output/.config"
	grep -Fxq 'BR2_GCC_TARGET_NAN="legacy"' "$buildroot_output/.config"
	grep -Fxq 'BR2_TOOLCHAIN_BUILDROOT=y' "$buildroot_output/.config"
	grep -Fxq 'BR2_TOOLCHAIN_BUILDROOT_GLIBC=y' "$buildroot_output/.config"
	grep -Fxq 'BR2_KERNEL_HEADERS_6_6=y' "$buildroot_output/.config"
	grep -Fxq 'BR2_BINUTILS_VERSION="2.43.1"' "$buildroot_output/.config"
	grep -Fxq 'BR2_GCC_VERSION="13.4.0"' "$buildroot_output/.config"
	grep -Fxq 'BR2_TOOLCHAIN_BUILDROOT_CXX=y' "$buildroot_output/.config"
	! grep -Eq '^BR2_TOOLCHAIN_EXTERNAL(=|_)' "$buildroot_output/.config"
	grep -Fxq "BR2_DL_DIR=\"$buildroot_dl\"" "$buildroot_output/.config"
	grep -Fxq "BR2_GLOBAL_PATCH_DIR=\"$project/patches\"" \
		"$buildroot_output/.config"
}

fetch() {
	[ -d "$sdk/.git" ] || git clone --filter=blob:none --no-checkout "$sdk_url" "$sdk"
	[ "$(git -C "$sdk" remote get-url origin)" = "$sdk_url" ]
	git -C "$sdk" fetch origin "$sdk_commit"
	git -C "$sdk" reset --hard "$sdk_commit"
	git -C "$sdk" clean -fdx
	git -C "$sdk" sparse-checkout set kernel/kernel-6.6 prebuilts/toolchains/mips-gcc720-glibc238
	git -C "$sdk" checkout --detach "$sdk_commit"
	[ "$(git -C "$sdk" rev-parse HEAD)" = "$sdk_commit" ]

	[ -d "$buildroot/.git" ] ||
		git clone --filter=blob:none --no-checkout "$buildroot_url" "$buildroot"
	[ "$(git -C "$buildroot" remote get-url origin)" = "$buildroot_url" ]
	git -C "$buildroot" fetch origin "$buildroot_commit"
	git -C "$buildroot" checkout --detach "$buildroot_commit"
	[ "$(git -C "$buildroot" rev-parse HEAD)" = "$buildroot_commit" ]
	prepare_buildroot

	[ -d "$klipper/.git" ] ||
		git clone --filter=blob:none --no-checkout "$klipper_url" "$klipper"
	[ "$(git -C "$klipper" remote get-url origin)" = "$klipper_url" ]
	git -C "$klipper" fetch origin "$klipper_commit"
	git -C "$klipper" checkout --detach "$klipper_commit"
	[ "$(git -C "$klipper" rev-parse HEAD)" = "$klipper_commit" ]

	brfetch="$work/buildroot-fetch"
	configure_buildroot "$brfetch"
	make -C "$buildroot" O="$brfetch" source
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
		"$klipper_overlay/usr/share/fre3nder/defaults"
	rsync -a --exclude=.git/ "$klipper/" \
		"$klipper_overlay/usr/share/klipper/"
	printf '%s\n' 'v0.13.0-733-g0499b3037-fre3nder-passive-uart-v1' > \
		"$klipper_overlay/usr/share/klipper/klippy/.version"
	install -m 0644 "$project/configs/klipper-f005/printer-f005-mainline.cfg" \
		"$klipper_overlay/usr/share/fre3nder/defaults/printer.cfg"
	install -m 0644 "$project/configs/x2000/f005-mcu-release.json" \
		"$klipper_overlay/usr/share/fre3nder/f005-mcu-release.json"
	install -m 0644 "$version_file" \
		"$klipper_overlay/usr/share/fre3nder/VERSION"
}

build_klipper_chelper() {
	buildroot_output=$1
	cc="$buildroot_output/host/bin/mipsel-buildroot-linux-gnu-gcc"
	strip="$buildroot_output/host/bin/mipsel-buildroot-linux-gnu-strip"
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
	readelf -h "$chelper/c_helper.so" | grep -Eq 'Flags:.*o32, mips32r2'
	! readelf -h "$chelper/c_helper.so" | grep -Fq 'nan2008'
	readelf -A "$chelper/c_helper.so" | grep -Fq 'ISA: MIPS32r2'
	readelf -A "$chelper/c_helper.so" |
		grep -Fq 'FP ABI: Hard float (32-bit CPU, Any FPU)'
	readelf -d "$chelper/c_helper.so" | grep -Fq 'Shared library: [libc.so.6]'
	readelf -d "$chelper/c_helper.so" | grep -Fq 'Shared library: [ld.so.1]'
}

stage_byof_firmware() {
	input_dir="$local_root/inputs/wifi"
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
	cp "$project/configs/x2000/ender3-v3-ke.dts" \
		"$k/module_drivers/dts/x2000/ender3-v3-ke.dts"
	git -C "$sdk" apply --check "$project/configs/x2000/ke-wlan.patch"
	git -C "$sdk" apply "$project/configs/x2000/ke-wlan.patch"
	git -C "$sdk" apply --reverse --check "$project/configs/x2000/ke-wlan.patch"

	if ! grep -q '^dtb-$(CONFIG_DT_ENDER3_V3_KE)' "$k/module_drivers/dts/Makefile"; then
		sed -i '/^obj-$(CONFIG_BUILTIN_DTB)/i dtb-$(CONFIG_DT_ENDER3_V3_KE) += x2000/ender3-v3-ke.dtb' "$k/module_drivers/dts/Makefile"
	fi
	if ! grep -q '^config DT_ENDER3_V3_KE$' "$k/arch/mips/xburst2/soc-x2000/Kconfig.DT"; then
		sed -i '/^endchoice$/i config DT_ENDER3_V3_KE\n\tbool "Ender-3 V3 KE"\n' "$k/arch/mips/xburst2/soc-x2000/Kconfig.DT"
	fi

	make -C "$k" ARCH=mips x2000_halley5_v30_linux_defconfig
	cat "$project/configs/x2000/kernel.fragment" >> "$k/.config"
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
	grep -Fxq 'CONFIG_OVERLAY_FS=y' "$k/.config"
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
	decoded="$work/fre3nder-x2000-kernel-only.dts"

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
	grep -Fxq 'BR2_PACKAGE_DROPBEAR_LOCALOPTIONS_FILE="/project/configs/x2000/dropbear.localoptions"' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON3=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON3_ZLIB=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON3_PYEXPAT=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON3_SQLITE=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON_PIP=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON_SETUPTOOLS=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON3_SSL=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_CA_CERTIFICATES=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON_PILLOW=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON_PYYAML=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON_TORNADO=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON_MARKUPSAFE=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON_CFFI=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON_GREENLET=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON_JINJA2=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON_MARKUPSAFE=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_PYTHON_SERIAL=y' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_PYTHON_CAN is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_ALSA_LIB is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_ALSA_UTILS is not set' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_OPENSSL=y' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_JPEG is not set' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_EXPAT=y' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_SQLITE=y' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_NCURSES is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_READLINE is not set' "$brout/.config"
	grep -Fxq 'BR2_PACKAGE_ZLIB=y' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_MTD is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_BUSYBOX_SHOW_OTHERS is not set' "$brout/.config"
	[ -z "$(find "$brout/build" -maxdepth 1 -type d \
		-name 'i2c-tools-*' -print -quit)" ]

	grep -Fxq 'CONFIG_I2CGET=y' "$busybox_config"
	grep -Fxq 'CONFIG_I2CSET=y' "$busybox_config"
	grep -Fxq 'CONFIG_I2CDUMP=y' "$busybox_config"
	grep -Fxq 'CONFIG_I2CDETECT=y' "$busybox_config"
	grep -Fxq 'CONFIG_I2CTRANSFER=y' "$busybox_config"
	grep -Fxq '# BR2_PACKAGE_INPUT_EVENT_DAEMON is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_SPI_TOOLS is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_SYSSTAT is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_IFUPDOWN_SCRIPTS is not set' "$brout/.config"
	[ -z "$(find "$brout/build" -maxdepth 1 -type d \
		-name 'bash-*' -print -quit)" ]
	[ ! -e "$target/bin/bash" ]
	[ "$(readlink "$target/bin/sh")" = busybox ]
	grep -Fxq 'CONFIG_ASH=y' "$busybox_config"
	grep -Fxq '# BR2_PACKAGE_ANDROID_TOOLS is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_DAEMON is not set' "$brout/.config"
	grep -Fxq '# BR2_PACKAGE_UTIL_LINUX is not set' "$brout/.config"
	grep -Fxq '# BR2_TARGET_GENERIC_REMOUNT_ROOTFS_RW is not set' "$brout/.config"
	grep -Fxq '# BR2_TARGET_ROOTFS_JFFS2 is not set' "$brout/.config"
	grep -Fxq '# BR2_TARGET_ROOTFS_UBIFS is not set' "$brout/.config"
	grep -Fxq 'BR2_TARGET_ROOTFS_SQUASHFS4_XZ=y' "$brout/.config"
	[ -x "$target/etc/init.d/fre3nder-root" ]
	for init_script in S10mdev S20fre3nder-provision \
		S40fre3nder-network S50dropbear S60fre3nder-klipper; do
		[ -x "$target/etc/init.d/$init_script" ]
	done
	[ ! -e "$target/etc/init.d/S51fre3nder-ssh-recovery-test" ]
	[ ! -e "$target/usr/share/fre3nder-ssh-recovery-test" ]
	printf '%s\n' \
		S20fre3nder-provision \
		S40fre3nder-network \
		S50dropbear \
		S60fre3nder-klipper | sort -C
	[ -n "$busybox_config" ]
	[ -n "$dropbear_options" ]
	grep -Fxq '# CONFIG_UDHCPD is not set' "$busybox_config"
	grep -Fxq 'CONFIG_UDHCPC=y' "$busybox_config"
	grep -Fxq 'CONFIG_NTPD=y' "$busybox_config"
	grep -Fxq '# CONFIG_FEATURE_NTPD_SERVER is not set' "$busybox_config"
	grep -Fxq '# CONFIG_FEATURE_NTPD_CONF is not set' "$busybox_config"
	grep -Fxq '# CONFIG_FEATURE_NTP_AUTH is not set' "$busybox_config"
	grep -Fxq '#define DROPBEAR_SVR_PASSWORD_AUTH 0' "$dropbear_options"
	[ -x "$target/sbin/udhcpc" ]
	[ -x "$target/usr/sbin/ntpd" ]
	[ -x "$target/sbin/blkid" ]
	[ -x "$target/sbin/pivot_root" ]
	[ -x "$target/bin/mount" ]
	[ -x "$target/bin/umount" ]
	[ ! -e "$target/usr/sbin/udhcpd" ]
	[ -x "$target/usr/sbin/wpa_supplicant" ]
	[ -x "$target/usr/sbin/dropbear" ]
	[ -x "$target/usr/bin/dropbearkey" ]
	[ -x "$target/usr/bin/python3" ]
	[ -x "$target/usr/libexec/fre3nder/f005-mcu-state" ]
	[ -x "$target/usr/libexec/fre3nder/f005-stock-to-fre3nder" ]
	[ -f "$target/usr/libexec/fre3nder/f005_bootloader.py" ]
	[ -f "$target/usr/share/klipper/COPYING" ]
	[ -f "$target/usr/share/klipper/klippy/klippy.py" ]
	[ -f "$target/usr/share/klipper/klippy/chelper/c_helper.so" ]
	[ -f "$target/usr/share/fre3nder/f005-mcu-release.json" ]
	cmp -s "$version_file" "$target/usr/share/fre3nder/VERSION"
	[ -f "$target/usr/share/fre3nder/defaults/printer.cfg" ]
	grep -Fxq 'x2000_passive_uart: True' \
		"$target/usr/share/fre3nder/defaults/printer.cfg"
	[ ! -e "$target/etc/klipper/printer.cfg" ]
	service="$target/etc/init.d/S60fre3nder-klipper"
	grep -Fq 'input_tty=$runtime/printer' "$service"
	grep -Fq 'set_status starting' "$service"
	grep -Fq '"$python" "$klippy" -I "$input_tty" -l "$log_file" "$config"' "$service"
	grep -Fq 'set_status startup-failed' "$service"
	grep -Fq 'rm -f "$pid_file" "$input_tty"' "$service"
	if grep -Fq '"$python" "$klippy" "$config" -l "$log_file"' "$service"; then
		echo 'Fre3nder RootFS contains obsolete Klippy /tmp input-TTY launch' >&2
		exit 1
	fi
	file "$target/usr/share/klipper/klippy/chelper/c_helper.so" |
		grep -q 'ELF 32-bit LSB shared object, MIPS, MIPS32 rel2'
	readelf -h "$target/usr/share/klipper/klippy/chelper/c_helper.so" |
		grep -Eq 'Flags:.*o32, mips32r2'
	! readelf -h "$target/usr/share/klipper/klippy/chelper/c_helper.so" |
		grep -Fq 'nan2008'
	readelf -A "$target/usr/share/klipper/klippy/chelper/c_helper.so" |
		grep -Fq 'FP ABI: Hard float (32-bit CPU, Any FPU)'
	if find "$target" -type f -name mcu_util -print -quit | grep -q .; then
		echo 'Fre3nder RootFS contains forbidden BYOF mcu_util' >&2
		exit 1
	fi
	[ ! -e "$target/init" ]
	[ -d "$target/dev/pts" ]
	[ -d "$target/home" ] && [ ! -L "$target/home" ]
	[ -d "$target/rom" ] && [ ! -L "$target/rom" ]
	[ -d "$target/mnt/fre3nder-root" ] && [ ! -L "$target/mnt/fre3nder-root" ]
	[ -d "$target/var" ] && [ ! -L "$target/var" ]
	[ "$(readlink "$target/var/run")" = ../run ]
	[ "$(readlink "$target/var/lock")" = ../run/lock ]
	[ -d "$target/root/.ssh" ] && [ ! -L "$target/root/.ssh" ]
	[ "$(readlink "$target/etc/resolv.conf")" = ../run/fre3nder/resolv.conf ]
	mkdir_line=$(grep -nF '::sysinit:/bin/mkdir -p /dev/pts' "$inittab" | cut -d: -f1)
	mount_line=$(grep -nF '::sysinit:/bin/mount -t devpts devpts /dev/pts' "$inittab" | cut -d: -f1)
	[ "$mkdir_line" -lt "$mount_line" ]
	grep -Fq '::sysinit:/bin/mount -t tmpfs -o mode=1777,nosuid,nodev tmpfs /tmp' \
		"$inittab"
	grep -Fq '"$mount_cmd" -t vfat -o ro,nosuid,nodev,noexec' \
		"$target/etc/init.d/S20fre3nder-provision"
	! grep -Eq 'blkid.*TYPE|TYPE=.*vfat' \
		"$target/etc/init.d/S20fre3nder-provision"
	grep -Fq 'usb_wait_seconds=${FRE3NDER_USB_WAIT_SECONDS:-10}' \
		"$target/etc/init.d/S20fre3nder-provision"
	grep -Fq 'multiple provisioning volumes found; refusing all' \
		"$target/etc/init.d/S20fre3nder-provision"
	[ ! -e "$target/persist" ]
	[ ! -e "$target/etc/init.d/S09fre3nder-storage" ]
	[ ! -e "$target/etc/init.d/S10fre3nder-persistence" ]
	root_setup="$target/etc/init.d/fre3nder-root"
	grep -Fxq '::sysinit:/etc/init.d/fre3nder-root start' "$inittab"
	root_setup_line=$(
		grep -nF '::sysinit:/etc/init.d/fre3nder-root start' "$inittab" |
		cut -d: -f1
	)
	rcs_line=$(
		grep -nF '::sysinit:/etc/init.d/rcS' "$inittab" |
		cut -d: -f1
	)
	[ "$root_setup_line" -lt "$rcs_line" ]
	grep -Fq 'LABEL="FRE3NDERSYS"' "$root_setup"
	grep -Fq 'LABEL="FRE3NDERHOME"' "$root_setup"
	! grep -Fq 'TYPE="ext4"' "$root_setup"
	[ "$(grep -Fc '"$mount_cmd" -t ext4 -o rw,nosuid,nodev' "$root_setup")" -eq 2 ]
	grep -Fq 'lowerdir=/,upperdir=$system_mount/upper,workdir=$system_mount/work' \
		"$root_setup"
	grep -Fq '"$pivot_root_cmd" "$new_root" "$new_root/rom"' "$root_setup"
	! grep -Eq 'fsck|mkfs|mke2fs|mmcblk0p(9|10)|/dev/sd[a-z]|FRE3NDERDATA' \
		"$root_setup"
	grep -Fq 'root_state=${FRE3NDER_ROOT_STATE:-/run/fre3nder-root}' \
		"$target/etc/init.d/S60fre3nder-klipper"
	grep -Fq 'while [ "$seconds" -lt 30 ]' \
		"$target/etc/init.d/S40fre3nder-network"
	grep -Fq 'Ethernet selected; DHCP lease acquired' \
		"$target/etc/init.d/S40fre3nder-network"
	grep -Fq 'lease_file=$runtime/lease' \
		"$target/etc/init.d/S40fre3nder-network"
	grep -Fq 'printf '\''%s\n'\'' "$interface" > "$lease_file"' \
		"$target/usr/libexec/fre3nder-udhcpc"
	grep -Fq '"$udhcpc" -f -i "$interface"' \
		"$target/etc/init.d/S40fre3nder-network"
	! grep -Eq 'udhcpc .*-[^ ]*b.*-[^ ]*q|udhcpc .*-[^ ]*q.*-[^ ]*b' \
		"$target/etc/init.d/S40fre3nder-network"
	grep -Fq '[ ! -s "$provisioning/enable_ssh" ]' \
		"$target/etc/init.d/S50dropbear"
	grep -Fq 'config=$provisioning/wpa_supplicant.conf' \
		"$target/etc/init.d/S40fre3nder-network"
	grep -Fq 'install -m 0600 "$provisioning/authorized_keys"' \
		"$target/etc/init.d/S50dropbear"
	grep -Fq '/dev/pts devpts ' "$target/etc/init.d/S50dropbear"
	grep -Fq 'dropbear_ed25519_host_key' "$target/etc/init.d/S50dropbear"
	grep -Fq 'root_active()' "$target/etc/init.d/S50dropbear"
	grep -Fq 'fre3nder_ssh_dir=${FRE3NDER_SSH_DIR:-$fre3nder_state_dir/ssh}' \
		"$target/etc/init.d/S50dropbear"
	! grep -E -i -q 's09x2000|fre3nderdata|usb|sd\[a-z\]|mmcblk0|p9|p10' \
		"$target/etc/init.d/S50dropbear"
	grep -Fq '"$dropbear" -r "$hostkey" -P "$pid_file"' \
		"$target/etc/init.d/S50dropbear"
	! grep -Eq '"\$dropbear"[[:space:]]+-s([[:space:]]|$)' \
		"$target/etc/init.d/S50dropbear"
	if find "$target" -type f \( -name authorized_keys -o -name wpa_supplicant.conf -o -name 'id_*' \) -print -quit | grep -q .; then
		echo 'Fre3nder RootFS contains credential files' >&2
		exit 1
	fi
	if find "$target" -type f -name enable_ssh -print -quit | grep -q .; then
		echo 'Fre3nder RootFS enables SSH at build time' >&2
		exit 1
	fi
	if find "$target" -type f -name '*dropbear*host*key*' -print -quit | grep -q .; then
		echo 'Fre3nder RootFS contains persistent Dropbear host keys' >&2
		exit 1
	fi
	if find "$target/root/.ssh" -mindepth 1 -print -quit | grep -q .; then
		echo 'Fre3nder RootFS contains SSH state' >&2
		exit 1
	fi
	if grep -R -I -E -q -- '-----BEGIN [A-Z ]*PRIVATE KEY-----|(^|[[:space:]])psk=' \
		"$target/etc" "$target/root" 2>/dev/null; then
		echo 'Fre3nder RootFS contains credential material' >&2
		exit 1
	fi
	if grep -R -E -i -q 'mmcblk0p(1|9|10)|ota:kernel|slot-b-selector|slot-b-revert' \
		"$target/etc/init.d" "$target/etc/inittab" "$target/etc/fstab" 2>/dev/null; then
		echo 'Fre3nder RootFS contains selector or reserved-partition logic' >&2
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
	prepare_buildroot
	k="$sdk/kernel/kernel-6.6"
	make -C "$k" -j"$jobs" ARCH=mips CROSS_COMPILE=mips-linux-gnu- \
		HOSTCFLAGS='-Wno-error=incompatible-pointer-types' xImage dtbs
	check_default_initramfs "$k"
	[ "$(make -s -C "$k" ARCH=mips kernelrelease)" = 6.6.18-rt23 ]

	brout="$work/buildroot-output-fre3nder"
	prepare_klipper_overlay
	extra_overlay="$wifi_overlay $klipper_overlay"
	out="$full_out"
	configure_buildroot "$brout" "$extra_overlay"
	make -C "$buildroot" O="$brout" -j"$jobs" toolchain
	build_klipper_chelper "$brout"
	make -C "$buildroot" O="$brout" -j"$jobs"
	check_rootfs "$brout"

	rm -rf -- "$out"
	mkdir -p "$out"
	cp "$k/arch/mips/boot/compressed/xImage" "$out/kernel.uImage"
	cp "$brout/images/rootfs.squashfs" "$out/rootfs.squashfs"
	cp "$k/module_drivers/dts/x2000/ender3-v3-ke.dtb" "$out/ender3-v3-ke.dtb"
	cp "$k/.config" "$out/effective-kernel-config"
	cp "$brout/.config" "$out/buildroot.config"

	export FULL_OUTPUT="$out"
	export version release_year release_number release_stage release_scope
	python3 - <<'PY'
import hashlib
import json
import os
import pathlib
import subprocess

out = pathlib.Path(os.environ["FULL_OUTPUT"])
artifact_names = [
    "buildroot.config",
    "effective-kernel-config",
    "ender3-v3-ke.dtb",
    "kernel.uImage",
    "rootfs.squashfs",
]
manifest = json.loads(pathlib.Path("/project/configs/x2000/sources.json").read_text())
manifest.update({
    "version": os.environ["version"],
    "release_year": int(os.environ["release_year"]),
    "release_number": int(os.environ["release_number"]),
    "release_stage": os.environ["release_stage"],
    "release_scope": os.environ["release_scope"],
})
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

	out="$kernel_out"
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
	brout="$work/buildroot-output-fre3nder"
	configure_buildroot "$brout" "$wifi_overlay $klipper_overlay"
	make -C "$buildroot" O="$brout" -j"${JOBS:-4}" toolchain
	build_klipper_chelper "$brout"
	make -C "$buildroot" O="$brout" rootfs-squashfs
	check_rootfs "$brout"

	out="$rootfs_out"
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
	*) echo 'usage: fre3nder-x2000 {fetch|build|build-kernel-only|build-rootfs-only}' >&2; exit 2 ;;
esac
