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
	printf 'BR2_ROOTFS_OVERLAY="%s/configs/x2000-prototype/rootfs-overlay"\n# BR2_TARGET_ROOTFS_EXT2 is not set\nBR2_TARGET_ROOTFS_SQUASHFS=y\nBR2_TARGET_ROOTFS_SQUASHFS_XZ=y\n# BR2_TARGET_ROOTFS_TAR is not set\n# BR2_PACKAGE_OPENCV4 is not set\n' "$project" >> "$brfetch/.config"
	make -C "$br" O="$brfetch" olddefconfig
	make -C "$br" O="$brfetch" source
}

prepare_kernel() {
	k="$sdk/kernel/kernel-6.6"
	git -C "$sdk" clean -fdx kernel/kernel-6.6
	git -C "$sdk" reset --hard "$sdk_commit"
	[ -e "$k/drivers/input/touchscreen/ns2009.c" ] || cp "$nebula/kernel/kernel-6.6/drivers/input/touchscreen/ns2009.c" "$k/drivers/input/touchscreen/ns2009.c"
	grep -q '^config TOUCHSCREEN_NS2009$' "$k/drivers/input/touchscreen/Kconfig" || printf '\nconfig TOUCHSCREEN_NS2009\n\ttristate "Nsiway NS2009 touchscreen"\n\tdepends on I2C\n\tselect INPUT_POLLDEV\n\thelp\n\t  Polled driver for Nsiway NS2009 touch controllers.\n' >> "$k/drivers/input/touchscreen/Kconfig"
	grep -q 'TOUCHSCREEN_NS2009' "$k/drivers/input/touchscreen/Makefile" || printf 'obj-$(CONFIG_TOUCHSCREEN_NS2009) += ns2009.o\n' >> "$k/drivers/input/touchscreen/Makefile"
	cp "$project/configs/x2000-prototype/ender3-v3-ke.dts" "$k/module_drivers/dts/x2000/ender3-v3-ke.dts"
	grep -q 'DT_ENDER3_V3_KE' "$k/module_drivers/dts/Makefile" || printf 'dtb-$(CONFIG_DT_ENDER3_V3_KE) += x2000/ender3-v3-ke.dtb\n' >> "$k/module_drivers/dts/Makefile"
	grep -q '^config DT_ENDER3_V3_KE$' "$k/arch/mips/xburst2/soc-x2000/Kconfig.DT" || printf '\nconfig DT_ENDER3_V3_KE\n\tbool "Ender-3 V3 KE"\n' >> "$k/arch/mips/xburst2/soc-x2000/Kconfig.DT"
	make -C "$k" ARCH=mips x2000_halley5_v30_linux_defconfig
	cat "$project/configs/x2000-prototype/kernel.fragment" >> "$k/.config"
	printf '# CONFIG_DT_HALLEY5_V30 is not set\nCONFIG_DT_ENDER3_V3_KE=y\n' >> "$k/.config"
	make -C "$k" ARCH=mips olddefconfig
}

build() {
	export PATH="$sdk/prebuilts/toolchains/mips-gcc720-glibc238/bin:$PATH"
	jobs=${JOBS:-4}
	prepare_kernel
	k="$sdk/kernel/kernel-6.6"
	make -C "$k" -j"$jobs" ARCH=mips CROSS_COMPILE=mips-linux-gnu- HOSTCFLAGS='-Wno-error=incompatible-pointer-types' uImage dtbs
	br="$sdk/buildroot"
	brout="$work/buildroot-output"
	make -C "$br" O="$brout" halley5_linux_minimal_defconfig
	sed -i "s#BR2_TOOLCHAIN_EXTERNAL_PATH=.*#BR2_TOOLCHAIN_EXTERNAL_PATH=\"$sdk/prebuilts/toolchains/mips-gcc720-glibc238\"#" "$brout/.config"
	printf 'BR2_ROOTFS_OVERLAY="%s/configs/x2000-prototype/rootfs-overlay"\n# BR2_TARGET_ROOTFS_EXT2 is not set\nBR2_TARGET_ROOTFS_SQUASHFS=y\nBR2_TARGET_ROOTFS_SQUASHFS_XZ=y\n# BR2_TARGET_ROOTFS_TAR is not set\n# BR2_PACKAGE_OPENCV4 is not set\n' "$project" >> "$brout/.config"
	make -C "$br" O="$brout" olddefconfig
	make -C "$br" O="$brout" -j"$jobs"
	mkdir -p "$out"
	cp "$k/arch/mips/boot/uImage" "$out/kernel.uImage"
	cp "$k/module_drivers/dts/x2000/ender3-v3-ke.dtb" "$out/ender3-v3-ke.dtb"
	cp "$brout/images/rootfs.squashfs" "$out/rootfs.squashfs"
	cp "$k/.config" "$out/kernel.config"
	cp "$brout/.config" "$out/buildroot.config"
	(cd "$out" && sha256sum buildroot.config ender3-v3-ke.dtb kernel.config kernel.uImage rootfs.squashfs) > "$out/SHA256SUMS"
	python3 - <<'PY'
import hashlib, json, pathlib
import subprocess
out = pathlib.Path('/project/local/phase3/x2000-prototype')
artifacts = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.iterdir()) if p.is_file() and p.name != 'build-manifest.json'}
manifest = json.loads((pathlib.Path('/project/configs/x2000-prototype/sources.json')).read_text())
manifest['artifacts'] = artifacts
manifest['project_commit'] = subprocess.check_output(['git', '-C', '/project', 'rev-parse', 'HEAD'], text=True).strip()
out.joinpath('build-manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
PY
	file "$out/kernel.uImage" "$out/ender3-v3-ke.dtb" "$out/rootfs.squashfs"
	readelf -h "$k/vmlinux"
	objdump -f "$k/vmlinux"
	dumpimage -l "$out/kernel.uImage"
	fdtdump "$out/ender3-v3-ke.dtb" | grep -E 'ender-3-v3-ke|nsiway,ns2009|10031000|13450000'
	grep -E 'CONFIG_(SMP|MMC_SDHCI_INGENIC|SPI_GPIO|SPI_SPIDEV|TOUCHSCREEN_NS2009|OVERLAY_FS|SQUASHFS|USB_DWC2|USB_VIDEO_CLASS|INGENIC_WDT)=y' "$out/kernel.config"
}

case "${1:-build}" in
	fetch) fetch ;;
	build) build ;;
	*) echo "usage: x2000-prototype {fetch|build}" >&2; exit 2 ;;
esac
