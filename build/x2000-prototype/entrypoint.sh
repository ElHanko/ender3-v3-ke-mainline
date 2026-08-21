#!/bin/sh
set -eu

project=/project
work=/work
sdk="$work/sdk"
nebula="$work/nebula"
out="$project/local/phase3/x2000-prototype"
sdk_url=https://github.com/Llixuma/ingenic-linux-kernel6.6-x2000-v1.0-20250221.git
sdk_commit=a98c2e1f22e4263ddd4153a4eca4db4dcfd2777b
nebula_url=https://github.com/coreflake1/NebulaOS-kernel.git
nebula_commit=8e97319a1754e264580ac39400a0c41139d2deb4

fetch() {
	[ -d "$sdk/.git" ] || git clone --filter=blob:none --no-checkout "$sdk_url" "$sdk"
	git -C "$sdk" sparse-checkout set kernel/kernel-6.6 buildroot prebuilts/toolchains/mips-gcc720-glibc238
	git -C "$sdk" checkout --detach "$sdk_commit"
	[ "$(git -C "$sdk" rev-parse HEAD)" = "$sdk_commit" ]
	[ -d "$nebula/.git" ] || git clone --filter=blob:none --no-checkout "$nebula_url" "$nebula"
	git -C "$nebula" sparse-checkout set kernel/kernel-6.6/drivers/input/touchscreen
	git -C "$nebula" checkout --detach "$nebula_commit"
	[ "$(git -C "$nebula" rev-parse HEAD)" = "$nebula_commit" ]
	br="$sdk/buildroot"
	brfetch="$work/buildroot-fetch"
	make -C "$br" O="$brfetch" halley5_linux_minimal_defconfig
	sed -i "s#BR2_TOOLCHAIN_EXTERNAL_PATH=.*#BR2_TOOLCHAIN_EXTERNAL_PATH=\"$sdk/prebuilts/toolchains/mips-gcc720-glibc238\"#" "$brfetch/.config"
	configure_buildroot "$brfetch"
	make -C "$br" O="$brfetch" source
}

configure_buildroot() {
	buildroot_output=$1
	provision_overlay=${2:-}
	slot_overlay=${3:-}
	rootfs_overlay="$project/configs/x2000-prototype/rootfs-overlay"
	[ -z "$provision_overlay" ] || rootfs_overlay="$rootfs_overlay $provision_overlay"
	[ -z "$slot_overlay" ] || rootfs_overlay="$rootfs_overlay $project/configs/x2000-prototype/slot-b-smoke-rootfs-overlay"
	sed -i "s#BR2_TOOLCHAIN_EXTERNAL_PATH=.*#BR2_TOOLCHAIN_EXTERNAL_PATH=\"$sdk/prebuilts/toolchains/mips-gcc720-glibc238\"#" "$buildroot_output/.config"
	cat "$project/configs/x2000-prototype/buildroot.fragment" >> "$buildroot_output/.config"
	printf 'BR2_ROOTFS_OVERLAY="%s"\n' "$rootfs_overlay" >> "$buildroot_output/.config"
	if [ -n "$slot_overlay" ]; then
		printf 'BR2_ROOTFS_POST_BUILD_SCRIPT="/project/configs/x2000-prototype/slot-b-smoke-post-build.sh"\n' >> "$buildroot_output/.config"
	fi
	make -C "$sdk/buildroot" O="$buildroot_output" olddefconfig
}

prepare_kernel() {
	slot_mode=${1:-false}
	k="$sdk/kernel/kernel-6.6"
	git -C "$sdk" clean -fdx kernel/kernel-6.6
	git -C "$sdk" reset --hard "$sdk_commit"
	[ -e "$k/drivers/input/touchscreen/ns2009.c" ] || cp "$nebula/kernel/kernel-6.6/drivers/input/touchscreen/ns2009.c" "$k/drivers/input/touchscreen/ns2009.c"
	grep -q '^config TOUCHSCREEN_NS2009$' "$k/drivers/input/touchscreen/Kconfig" || printf '\nconfig TOUCHSCREEN_NS2009\n\ttristate "Nsiway NS2009 touchscreen"\n\tdepends on I2C\n\tselect INPUT_POLLDEV\n\thelp\n\t  Polled driver for Nsiway NS2009 touch controllers.\n' >> "$k/drivers/input/touchscreen/Kconfig"
	grep -q 'TOUCHSCREEN_NS2009' "$k/drivers/input/touchscreen/Makefile" || printf 'obj-$(CONFIG_TOUCHSCREEN_NS2009) += ns2009.o\n' >> "$k/drivers/input/touchscreen/Makefile"
	dt="$k/module_drivers/dts/x2000/ender3-v3-ke.dts"
	cp "$project/configs/x2000-prototype/ender3-v3-ke.dts" "$dt"
	if [ "$slot_mode" = true ]; then
		# Rewrite only the generated Buildtree copy, never the committed DTS.
		sed -i 's#bootargs = "console=ttyS4,115200";#bootargs = "console=ttyS4,115200 root=/dev/mmcblk0p8 rootwait rootfstype=squashfs ro";#' "$dt"
		grep -q 'root=/dev/mmcblk0p8 rootwait rootfstype=squashfs ro' "$dt"
	fi
	if ! grep -q '^dtb-$(CONFIG_DT_ENDER3_V3_KE)' "$k/module_drivers/dts/Makefile"; then
		sed -i '/^obj-$(CONFIG_BUILTIN_DTB)/i dtb-$(CONFIG_DT_ENDER3_V3_KE) += x2000/ender3-v3-ke.dtb' "$k/module_drivers/dts/Makefile"
	fi
	if ! grep -q '^config DT_ENDER3_V3_KE$' "$k/arch/mips/xburst2/soc-x2000/Kconfig.DT"; then
		sed -i '/^endchoice$/i config DT_ENDER3_V3_KE\n\tbool "Ender-3 V3 KE"\n' "$k/arch/mips/xburst2/soc-x2000/Kconfig.DT"
	fi
	make -C "$k" ARCH=mips x2000_halley5_v30_linux_defconfig
	cat "$project/configs/x2000-prototype/kernel.fragment" >> "$k/.config"
	printf 'CONFIG_DT_ENDER3_V3_KE=y\n' >> "$k/.config"
	make -C "$k" ARCH=mips olddefconfig
	grep -q '^# CONFIG_DT_HALLEY5_V30 is not set$' "$k/.config"
	grep -q '^CONFIG_DT_ENDER3_V3_KE=y$' "$k/.config"
}

build_kernel() {
	k="$sdk/kernel/kernel-6.6"
	make -C "$k" -j"$jobs" ARCH=mips CROSS_COMPILE=mips-linux-gnu- HOSTCFLAGS='-Wno-error=incompatible-pointer-types' uImage dtbs
}

make_initramfs() {
	k="$sdk/kernel/kernel-6.6"
	brout=$1
	ramfs=$2
	first="$ramfs.first"
	second="$ramfs.second"
	find "$brout/target" -exec touch -h -d @0 {} +
	if [ ! -x "$k/usr/gen_init_cpio" ]; then
		cc -O2 -Wall "$k/usr/gen_init_cpio.c" -o "$k/usr/gen_init_cpio"
	fi
	(cd "$k" && ./usr/gen_initramfs.sh -u squash -g squash -d @0 -o "$first" "$brout/target")
	(cd "$k" && ./usr/gen_initramfs.sh -u squash -g squash -d @0 -o "$second" "$brout/target")
	cmp -s "$first" "$second"
	mv "$first" "$ramfs"
	rm -f "$second"
	[ -L "$brout/target/init" ]
	[ "$(readlink "$brout/target/init")" = sbin/init ]
}

configure_ramboot_kernel() {
	k="$sdk/kernel/kernel-6.6"
	ramfs=$1
	cat >> "$k/.config" <<EOF
CONFIG_BLK_DEV_INITRD=y
CONFIG_INITRAMFS_SOURCE="$ramfs"
CONFIG_INITRAMFS_COMPRESSION_GZIP=y
EOF
	make -C "$k" ARCH=mips olddefconfig
	grep -q '^CONFIG_BLK_DEV_INITRD=y$' "$k/.config"
	grep -q '^CONFIG_INITRAMFS_COMPRESSION_GZIP=y$' "$k/.config"
	grep -q '^CONFIG_INITRAMFS_SOURCE="' "$k/.config"
}

check_ramroot() {
	brout=$1
	if grep -R -E -q 'mmcblk0p(7|8|9|10)|rootfstype=squashfs|mke2fs|(^|[ /])fsck([ ;]|$)|swapon|/usr/data|overlay' \
		"$brout/target/etc/init.d" "$brout/target/etc/fstab" "$brout/target/etc/inittab" 2>/dev/null; then
		echo 'ramboot rootfs contains a forbidden persistent-storage action' >&2
		exit 1
	fi
	[ -e "$brout/target/sbin/init" ]
	[ -L "$brout/target/init" ]
}

check_generic_credentials() {
	brout=$1
	if find "$brout/target" -type f \( -name authorized_keys -o -name 'id_*' \) -print -quit | grep -q .; then
		echo 'generic ramboot target contains credential files' >&2
		exit 1
	fi
	if grep -R -I -E -q 'BEGIN [A-Z ]*PRIVATE KEY|(^|[[:space:]])psk=|authorized_keys' "$brout/target/etc" "$brout/target/root" 2>/dev/null; then
		echo 'generic ramboot target contains credential material' >&2
		exit 1
	fi
}

check_slot_b_rootfs() {
	brout=$1
	target="$brout/target"
	if grep -R -E -q 'mmcblk0p(9|10)|mount[[:space:]]+-a|mke2fs|(^|[ /])fsck([ ;]|$)|swapon|/usr/data|/overlay|ttyS1.*(getty|stty)' \
		"$target/etc/init.d" "$target/etc/fstab" "$target/etc/inittab" 2>/dev/null; then
		echo 'slot-b-smoke rootfs contains a forbidden persistent-storage or ttyS1 action' >&2
		exit 1
	fi
	[ -e "$target/sbin/init" ]
	[ -x "$target/usr/libexec/slot-b-selector" ]
	[ -x "$target/etc/init.d/S00slot-b-revert" ]
	[ -x "$target/etc/init.d/S01slot-b-smoke-reboot" ]
}

build() {
	provisioned=${1:-false}
	ramboot=${2:-false}
	slot_b_smoke=${3:-false}
	export PATH="$sdk/prebuilts/toolchains/mips-gcc720-glibc238/bin:$PATH"
	jobs=${JOBS:-4}
	[ "$slot_b_smoke" = false ] || {
		[ "$provisioned" = false ] || { echo 'slot-b-smoke cannot be provisioned' >&2; exit 2; }
		[ "$ramboot" = false ] || { echo 'slot-b-smoke cannot be ramboot' >&2; exit 2; }
	}
	prepare_kernel "$slot_b_smoke"
	if [ "$ramboot" != true ]; then
		build_kernel
	fi
	br="$sdk/buildroot"
	if [ "$slot_b_smoke" = true ]; then
		brout="$work/buildroot-output-slot-b-smoke"
		make -C "$br" O="$brout" halley5_linux_minimal_defconfig
		configure_buildroot "$brout" "" true
		out="$project/local/phase3/x2000-slot-b-smoke"
	elif [ "$provisioned" = true ]; then
		brout="$work/buildroot-output-provisioned"
		make -C "$br" O="$brout" halley5_linux_minimal_defconfig
		provision="$project/local/phase3/provision"
		[ -r "$provision/wpa_supplicant.conf" ]
		[ -r "$provision/authorized_keys" ]
		provision_overlay="$work/provision-overlay"
		install -d -m 0700 "$provision_overlay/etc/wpa_supplicant" "$provision_overlay/root/.ssh"
		install -m 0600 "$provision/wpa_supplicant.conf" "$provision_overlay/etc/wpa_supplicant/wpa_supplicant.conf"
		install -m 0600 "$provision/authorized_keys" "$provision_overlay/root/.ssh/authorized_keys"
		configure_buildroot "$brout" "$provision_overlay"
		if [ "$ramboot" = true ]; then
			out="$project/local/phase3/x2000-prototype-ramboot-provisioned"
		else
			out="$project/local/phase3/x2000-prototype-provisioned"
		fi
	else
		brout="$work/buildroot-output-generic"
		make -C "$br" O="$brout" halley5_linux_minimal_defconfig
		configure_buildroot "$brout"
		if [ "$ramboot" = true ]; then
			out="$project/local/phase3/x2000-prototype-ramboot"
		else
			out="$project/local/phase3/x2000-prototype"
		fi
	fi
	make -C "$br" O="$brout" -j"$jobs"
	if [ "$ramboot" = true ]; then
		check_ramroot "$brout"
		if [ "$provisioned" != true ]; then
			check_generic_credentials "$brout"
		fi
		ramfs="$work/$(basename "$out").cpio"
		configure_ramboot_kernel "$ramfs"
		make_initramfs "$brout" "$ramfs"
		build_kernel
	elif [ "$slot_b_smoke" = true ]; then
		check_slot_b_rootfs "$brout"
	fi
	mkdir -p "$out"
	if [ "$slot_b_smoke" = true ]; then
		cp "$k/arch/mips/boot/uImage" "$out/kernel-slot-b.uImage"
		cp "$k/.config" "$out/effective-kernel-config"
		cp "$k/module_drivers/dts/x2000/ender3-v3-ke.dtb" "$out/ender3-v3-ke-slot-b.dtb"
	elif [ "$ramboot" = true ]; then
		cp "$k/arch/mips/boot/uImage" "$out/kernel-ramboot.uImage"
		cp "$k/.config" "$out/kernel-ramboot.config"
	else
		cp "$k/arch/mips/boot/uImage" "$out/kernel.uImage"
		cp "$k/.config" "$out/kernel.config"
	fi
	[ "$slot_b_smoke" = true ] || cp "$k/module_drivers/dts/x2000/ender3-v3-ke.dtb" "$out/ender3-v3-ke.dtb"
	if [ "$slot_b_smoke" = true ]; then
		cp "$brout/images/rootfs.squashfs" "$out/rootfs-slot-b.squashfs"
	else
		cp "$brout/images/rootfs.squashfs" "$out/rootfs.squashfs"
	fi
	cp "$brout/.config" "$out/buildroot.config"
	if [ "$slot_b_smoke" = true ]; then
		(cd "$out" && sha256sum buildroot.config effective-kernel-config ender3-v3-ke-slot-b.dtb kernel-slot-b.uImage rootfs-slot-b.squashfs) > "$out/SHA256SUMS"
	elif [ "$ramboot" = true ]; then
		(cd "$out" && sha256sum buildroot.config ender3-v3-ke.dtb kernel-ramboot.config kernel-ramboot.uImage rootfs.squashfs) > "$out/SHA256SUMS"
	else
		(cd "$out" && sha256sum buildroot.config ender3-v3-ke.dtb kernel.config kernel.uImage rootfs.squashfs) > "$out/SHA256SUMS"
	fi
	export PROTOTYPE_OUTPUT="$out"
	export PROTOTYPE_LOCAL_PROVISIONING="$provisioned"
	export PROTOTYPE_RAMBOOT="$ramboot"
	export PROTOTYPE_SLOT_B_SMOKE="$slot_b_smoke"
	python3 - <<'PY'
import hashlib, json, os, pathlib
import subprocess
out = pathlib.Path(os.environ['PROTOTYPE_OUTPUT'])
artifacts = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.iterdir()) if p.is_file() and p.name != 'build-manifest.json'}
manifest = json.loads((pathlib.Path('/project/configs/x2000-prototype/sources.json')).read_text())
manifest['local_provisioning'] = os.environ['PROTOTYPE_LOCAL_PROVISIONING'] == 'true'
manifest['ramboot'] = os.environ['PROTOTYPE_RAMBOOT'] == 'true'
if os.environ['PROTOTYPE_SLOT_B_SMOKE'] == 'true':
    manifest['slot_b_smoke'] = True
    manifest['slot_b_bootargs'] = 'console=ttyS4,115200 root=/dev/mmcblk0p8 rootwait rootfstype=squashfs ro'
manifest['artifacts'] = artifacts
manifest['project_commit'] = subprocess.check_output(['git', '-C', '/project', 'rev-parse', 'HEAD'], text=True).strip()
out.joinpath('build-manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
PY
	if [ "$slot_b_smoke" = true ]; then
		file "$out/kernel-slot-b.uImage" "$out/ender3-v3-ke-slot-b.dtb" "$out/rootfs-slot-b.squashfs"
	elif [ "$ramboot" = true ]; then
		file "$out/kernel-ramboot.uImage" "$out/ender3-v3-ke.dtb" "$out/rootfs.squashfs"
	else
		file "$out/kernel.uImage" "$out/ender3-v3-ke.dtb" "$out/rootfs.squashfs"
	fi
	readelf -h "$k/vmlinux"
	objdump -f "$k/vmlinux"
	if [ "$slot_b_smoke" = true ]; then
		dumpimage -l "$out/kernel-slot-b.uImage"
		[ "$(stat -c '%s' "$out/kernel-slot-b.uImage")" -lt 8388608 ]
		[ "$(stat -c '%s' "$out/rootfs-slot-b.squashfs")" -lt 524288000 ]
		! grep -q '^CONFIG_BLK_DEV_INITRD=y$' "$out/effective-kernel-config"
		! grep -q '^CONFIG_INITRAMFS_SOURCE=' "$out/effective-kernel-config"
		grep -q '^CONFIG_BUILTIN_DTB=y$' "$out/effective-kernel-config"
		grep -q '^CONFIG_MIPS_CMDLINE_FROM_DTB=y$' "$out/effective-kernel-config"
	elif [ "$ramboot" = true ]; then
		dumpimage -l "$out/kernel-ramboot.uImage"
		nm -C --defined-only "$k/vmlinux" | grep -q '__initramfs_start'
		nm -C --defined-only "$k/vmlinux" | grep -q '__initramfs_size'
		grep -q '^CONFIG_BLK_DEV_INITRD=y$' "$out/kernel-ramboot.config"
		grep -q '^CONFIG_INITRAMFS_COMPRESSION_GZIP=y$' "$out/kernel-ramboot.config"
	else
		dumpimage -l "$out/kernel.uImage"
	fi
	if [ "$slot_b_smoke" = true ]; then
		fdtdump "$out/ender3-v3-ke-slot-b.dtb" 2>&1 | grep -E 'ender-3-v3-ke|nsiway,ns2009|10031000|13450000'
		grep -E 'CONFIG_(SMP|MMC_SDHCI_INGENIC|SPI_GPIO|SPI_SPIDEV|TOUCHSCREEN_NS2009|OVERLAY_FS|SQUASHFS|USB_DWC2|USB_VIDEO_CLASS|INGENIC_WDT)=y' "$out/effective-kernel-config"
		! strings "$k/vmlinux" | grep -q 'ingenic,halley5'
		strings "$k/vmlinux" | grep -q 'creality,ender-3-v3-ke'
	elif [ "$ramboot" = true ]; then
		fdtdump "$out/ender3-v3-ke.dtb" 2>&1 | grep -E 'ender-3-v3-ke|nsiway,ns2009|10031000|13450000'
		grep -E 'CONFIG_(SMP|MMC_SDHCI_INGENIC|SPI_GPIO|SPI_SPIDEV|TOUCHSCREEN_NS2009|OVERLAY_FS|SQUASHFS|USB_DWC2|USB_VIDEO_CLASS|INGENIC_WDT)=y' "$out/kernel-ramboot.config"
		! strings "$k/vmlinux" | grep -q 'ingenic,halley5'
		strings "$k/vmlinux" | grep -q 'creality,ender-3-v3-ke'
	else
		fdtdump "$out/ender3-v3-ke.dtb" 2>&1 | grep -E 'ender-3-v3-ke|nsiway,ns2009|10031000|13450000'
		grep -E 'CONFIG_(SMP|MMC_SDHCI_INGENIC|SPI_GPIO|SPI_SPIDEV|TOUCHSCREEN_NS2009|OVERLAY_FS|SQUASHFS|USB_DWC2|USB_VIDEO_CLASS|INGENIC_WDT)=y' "$out/kernel.config"
	fi
}

case "${1:-build}" in
	fetch) fetch ;;
	build) build false false ;;
	build-provisioned) build true false ;;
	build-ramboot) build false true ;;
	build-ramboot-provisioned) build true true ;;
	build-slot-b-smoke) build false false true ;;
	*) echo "usage: x2000-prototype {fetch|build|build-provisioned|build-ramboot|build-ramboot-provisioned|build-slot-b-smoke}" >&2; exit 2 ;;
esac
