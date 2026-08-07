# SSH command log

Inventory date: 2026-08-07. All successful inventory calls used the required
non-interactive form:

```text
ssh -o BatchMode=yes <printer-host> '<remote command>'
```

No remote redirection, file creation, file change, deletion, service control,
mount operation, backup, flash, or update was initiated by an inventory command.
Pipes below only filtered command output. Commands which read scripts did not
execute those scripts. This public log is intentionally sanitized and is not
copy-paste executable where angle-bracket placeholders occur.

## Successful calls

### 1. Connectivity/kernel check

```sh
ssh -o BatchMode=yes <printer-host> 'uname -a'
```

### 2. OS, CPU, RAM, and device-tree overview

```sh
ssh -o BatchMode=yes <printer-host> 'date; uname -a; uname -m; cat /etc/os-release; cat /proc/version; cat /proc/cpuinfo; cat /proc/meminfo; cat /proc/uptime; cat /proc/loadavg; cat /etc/hostname; id; busybox; ls -l /sys/firmware; ls -l /sys/firmware/devicetree/base; cat /sys/firmware/devicetree/base/model; cat /sys/firmware/devicetree/base/compatible'
```

### 3. Storage, partitions, mounts, and device nodes

```sh
ssh -o BatchMode=yes <printer-host> 'cat /proc/partitions; cat /proc/mtd; cat /proc/cmdline; cat /proc/mounts; mount; df -h; df -T; ls -l /dev/mtd*; ls -l /dev/mtdblock*; ls -l /dev/mmcblk*; ls -l /dev/sd*; ls -l /sys/class/mtd; ls -l /sys/class/block; blkid; fdisk -l'
```

### 4. Init, process/socket overview, and modules

```sh
ssh -o BatchMode=yes <printer-host> 'readlink /sbin/init; readlink /linuxrc; ls -l /sbin/init /linuxrc /etc/inittab /etc/init.d /etc/rcS.d /etc/rc.d; cat /etc/inittab; cat /etc/init.d/rcS; find /etc/init.d -maxdepth 2 -type f -print; find /etc/rcS.d -maxdepth 1 -print; find /etc/rc.d -maxdepth 2 -print; ps -ww; cat /proc/net/unix; netstat -lntup; lsmod'
```

`ps -ww` and `netstat -lntup` reported unsupported BusyBox options; later calls
used supported forms.

### 5. eMMC identity, sizes, and relevant kernel messages

```sh
ssh -o BatchMode=yes <printer-host> 'cat /sys/class/mmc_host/mmc0/mmc0:0001/type; cat /sys/class/mmc_host/mmc0/mmc0:0001/name; cat /sys/class/mmc_host/mmc0/mmc0:0001/manfid; cat /sys/class/mmc_host/mmc0/mmc0:0001/oemid; cat /sys/class/mmc_host/mmc0/mmc0:0001/serial; cat /sys/class/mmc_host/mmc0/mmc0:0001/date; cat /sys/class/mmc_host/mmc0/mmc0:0001/fwrev; cat /sys/class/mmc_host/mmc0/mmc0:0001/hwrev; cat /sys/class/mmc_host/mmc0/mmc0:0001/cid; cat /sys/class/mmc_host/mmc0/mmc0:0001/csd; cat /sys/class/mmc_host/mmc0/mmc0:0001/ext_csd; cat /sys/class/block/mmcblk0/size; cat /sys/class/block/mmcblk0/ro; cat /sys/class/block/mmcblk0boot0/size; cat /sys/class/block/mmcblk0boot0/ro; cat /sys/class/block/mmcblk0boot1/size; cat /sys/class/block/mmcblk0boot1/ro; cat /sys/class/block/mmcblk0rpmb/size; for p in /sys/class/block/mmcblk0p*; do cat $p/uevent; done; dmesg | grep -Ei "mmc|partition|gpt|rootfs|squashfs|overlay|boot|recovery|ota"'
```

### 6. Relevant boot/service scripts

```sh
ssh -o BatchMode=yes <printer-host> 'cat /etc/mount_mmc_ext4_overlay.sh; cat /etc/init.d/S02mount_mmc_ext4; cat /etc/init.d/S13mcu_update; cat /etc/init.d/S55klipper_service; cat /etc/init.d/S56moonraker_service; cat /etc/init.d/S57klipper_mcu; cat /etc/init.d/S58factoryreset; cat /etc/init.d/S96wipe_data; cat /etc/init.d/<local-web-service>; cat /etc/init.d/<local-package-service>; cat /etc/init.d/<local-integration-service>; cat /etc/init.d/S70cx_ai_middleware; cat /etc/init.d/S97webrtc; cat /etc/init.d/S98swap; cat /etc/init.d/S99start_app'
```

### 7. Initial process/path discovery

```sh
ssh -o BatchMode=yes <printer-host> 'ps; ps -o pid,ppid,user,stat,args; netstat -lnt; netstat -lnu; netstat -lnx; find /usr/data -maxdepth 3 -type d -print; ls -la /usr/data; ls -la /usr/data/printer_data; ls -la /usr/data/printer_data/config; ls -la /usr/data/printer_data/logs; ls -la /usr/data/printer_data/comms; find /usr/share -maxdepth 4 -name klippy.py -print; find /usr/data -maxdepth 6 -name klippy.py -print; find <local-package-root> -maxdepth 6 -name klippy.py -print; find /root -maxdepth 6 -name klippy.py -print; find /usr/data -maxdepth 6 -name printer.cfg -print; find /usr/data -maxdepth 6 -name moonraker.conf -print'
```

### 8. Exact service processes, file descriptors, and listeners

```sh
ssh -o BatchMode=yes <printer-host> 'ps; ps -o pid,ppid,user,stat,args; cat /var/run/klippy.pid; cat /var/run/moonraker.pid; cat /var/run/klipper_mcu.pid; ls -l /proc/$(cat /var/run/klippy.pid)/exe /proc/$(cat /var/run/klippy.pid)/cwd /proc/$(cat /var/run/klippy.pid)/fd; ls -l /proc/$(cat /var/run/moonraker.pid)/exe /proc/$(cat /var/run/moonraker.pid)/cwd /proc/$(cat /var/run/moonraker.pid)/fd; ls -l /proc/$(cat /var/run/klipper_mcu.pid)/exe /proc/$(cat /var/run/klipper_mcu.pid)/cwd /proc/$(cat /var/run/klipper_mcu.pid)/fd; netstat -lnt; netstat -lnu'
```

### 9. Active printer configuration and section index

```sh
ssh -o BatchMode=yes <printer-host> 'cat /usr/data/printer_data/config/printer.cfg; cat /usr/data/printer_data/config/printer_params.cfg; cat /usr/data/printer_data/config/sensorless.cfg; cat /usr/data/printer_data/config/gcode_macro.cfg; cat /usr/data/printer_data/config/factory_printer.cfg; grep -n "^\[include" /usr/data/printer_data/config/*.cfg; grep -n -Ei "^\[(mcu|mcu |stepper_|extruder|heater|temperature|fan|controller_fan|heater_fan|probe|prtouch|load|bed_mesh|input_shaper|adxl|resonance|filament|output_pin|gcode_macro)" /usr/data/printer_data/config/*.cfg'
```

### 10. Stock Klipper tree, Python environment, modules, and logs

```sh
ssh -o BatchMode=yes <printer-host> 'ls -la /usr/share/klipper; ls -la /usr/share/klipper/klippy; ls -la /usr/share/klippy-env/bin; /usr/share/klippy-env/bin/python --version; find /usr/share/klippy-env/lib -maxdepth 3 -type d -name site-packages -print; find /usr/share/klippy-env/lib/python3.7/site-packages -maxdepth 1 -print; find /usr/share/klipper/klippy/extras -maxdepth 1 -type f -print; grep -R -l -Ei "prtouch|loadcell|hx711|z_compensate|creality|cx_" /usr/share/klipper/klippy; head -120 /usr/data/printer_data/logs/klippy.log; tail -500 /usr/data/printer_data/logs/klippy.log | grep -Ei "version|mcu|start|config|error|warn"'
```

BusyBox rejected uppercase `grep -R`; the module list and later name comparison
provided the required evidence.

### 11. Local comparison tree, Moonraker, and web files

```sh
ssh -o BatchMode=yes <printer-host> 'cat <local-klipper-tree>/.git/HEAD; cat <local-klipper-tree>/.git/packed-refs; find <local-klipper-tree>/.git/refs -maxdepth 3 -type f -print; cat <local-klipper-tree>/.git/refs/heads/master; find <local-klipper-tree>/klippy/extras -maxdepth 1 -type f -print; cat /usr/data/moonraker/moonraker/.git/HEAD; cat /usr/data/moonraker/moonraker/.git/packed-refs; find /usr/data/moonraker/moonraker/.git/refs -maxdepth 3 -type f -print; cat /usr/data/moonraker/moonraker/.git/refs/heads/master; /usr/data/moonraker/moonraker-env/bin/python --version; ls -la /usr/data/moonraker/moonraker-env/lib; cat /usr/data/printer_data/config/moonraker.conf; head -120 /usr/data/printer_data/logs/moonraker.log; cat <local-web-proxy-config>; find <local-web-ui> -maxdepth 2 -type f -print; ls -la <local-web-ui>'
```

### 12. Klipper version evidence and Git metadata checks

```sh
ssh -o BatchMode=yes <printer-host> 'grep -n -m 20 -Ei "git version|software_version|start printer at|klipper version|loaded mcu" /usr/data/printer_data/logs/klippy.log; tail -4000 /usr/data/printer_data/logs/klippy.log | grep -Ei "start printer at|loaded mcu|software_version|mcu.*version|git version"; cat <local-klipper-tree>/.git/HEAD; cat <local-klipper-tree>/.git/packed-refs; ls -la <local-klipper-tree>/.git/refs/heads; cat <local-klipper-tree>/.git/refs/heads/master; cat <local-klipper-tree>/.git/refs/heads/work; cat <local-klipper-tree>/.git/refs/heads/main; cat <local-klipper-tree>/.git/config; ls -la /usr/share/klipper/.git; cat <local-web-ui>/.version; cat <local-web-ui>/release_info.json'
```

This read produced unexpectedly large log lines containing complete Klipper status
objects. No subsequent full-status query was made.

### 13. Focused Moonraker and web versions/routes

```sh
ssh -o BatchMode=yes <printer-host> 'cat /usr/data/moonraker/moonraker/.git/HEAD; cat /usr/data/moonraker/moonraker/.git/packed-refs; ls -la /usr/data/moonraker/moonraker/.git/refs/heads; cat /usr/data/moonraker/moonraker/.git/refs/heads/master; cat /usr/data/moonraker/moonraker/.git/refs/heads/main; /usr/data/moonraker/moonraker-env/bin/python --version; grep -m 10 -Ei "version:|commit:|branch:|source_checksum|package_version" /usr/data/printer_data/logs/moonraker.log; grep -n -E "^\[|host:|port:|klippy_uds_address:|path:|origin:|channel:|type:" /usr/data/printer_data/config/moonraker.conf; grep -n -E "listen|root |proxy_pass|server_name" <local-web-proxy-config>'
```

### 14. MCU images, versions, and device paths

```sh
ssh -o BatchMode=yes <printer-host> 'find /usr/share/klipper/fw -maxdepth 4 -type f -print; ls -l /usr/share/klipper/fw/F005; cat /tmp/.mcu_version; tail -80 /tmp/mcu_update.log; ls -l /dev/ttyS* /dev/serial* /dev/ttyUSB* /dev/ttyACM* /dev/can* /tmp/klipper_host_mcu /tmp/klippy_uds; find /sys/class/tty -maxdepth 1 -name "ttyS*" -print; cat /usr/bin/get_sn_mac.sh; cat /usr/data/machine_production_info; ls -la /usr/data/creality/upgrade'
```

`get_sn_mac.sh` was read but not executed; it internally contains `dd`. Device
identity output from `machine_production_info` is intentionally not reproduced in
the other documents.

### 15. Update/recovery files and upgrade-server strings

```sh
ssh -o BatchMode=yes <printer-host> 'ls /usr/bin | grep -Ei "upgrade|update|ota|recover|factory|flash|mcu|wipe|reset|boot"; ls /usr/sbin | grep -Ei "upgrade|update|ota|recover|factory|flash|mcu|wipe|reset|boot"; find /etc -maxdepth 3 -type f -iname "*upgrade*" -print; find /etc -maxdepth 3 -type f -iname "*update*" -print; find /etc -maxdepth 3 -type f -iname "*factory*" -print; find /usr/share -maxdepth 4 -type f -iname "*upgrade*" -print; find /usr/share -maxdepth 4 -type f -iname "*update*" -print; find /usr/share -maxdepth 4 -type f -iname "*recovery*" -print; find /usr/data/creality -maxdepth 5 -type f -print; cat /usr/bin/mount_mmc_ext4.sh; strings /usr/bin/upgrade-server | grep -Ei "mmcblk|rootfs|kernel|rtos|ota|recovery|upgrade|update|squashfs|userdata"'
```

### 16. Overlay differences and previous local migration script

```sh
ssh -o BatchMode=yes <printer-host> 'find /overlay/upper/etc/init.d -maxdepth 1 -type f -print; find /overlay/upper/usr/bin -maxdepth 2 -type f -print; find /overlay/upper/usr/share/klipper -maxdepth 5 -type f -print; du -h -s /overlay/upper/*; sha256sum /rom/etc/init.d/S55klipper_service /etc/init.d/S55klipper_service /rom/usr/share/klipper/klippy/klippy.py /usr/share/klipper/klippy/klippy.py; cat <local-migration-script>; grep -n -Ei "klipper|moonraker|upstream|rollback|backup|service|python" <local-migration-script>'
```

### 17. OTA scripts and Creality version/config logs

```sh
ssh -o BatchMode=yes <printer-host> 'ls -la /etc/ota_bin; cat /etc/ota_bin/get_ota_current_version.sh; cat /etc/ota_bin/get_ota_board_name.sh; cat /etc/ota_bin/local_ota_update.sh; cat /etc/ota_bin/network_ota_update.sh; cat /etc/ota_bin/ota_update_kernel.sh; cat /etc/ota_bin/ota_update_rootfs_squashfs.sh; cat /etc/ota_bin/ota_update_rtos_bin.sh; cat /usr/data/creality/userdata/config/system_version.json; cat /usr/data/creality/userdata/config/device_structure_config.json; cat /usr/data/creality/userdata/config/system_config.json; tail -120 /usr/data/creality/userdata/log/upgrade-server.log'
```

`system_config.json` exposed device identity to the local command output. Those
values are redacted from the repository documentation.

### 18. A/B helper logic, boot paths, and filesystem signatures

```sh
ssh -o BatchMode=yes <printer-host> 'cat /etc/ota_bin/ota_local_method.sh; cat /etc/ota_bin/ota_utils.sh; cat /etc/ota_info; cat /etc/fstab; find /etc -maxdepth 3 -type f -iname "*uboot*" -print; find /etc -maxdepth 3 -type f -iname "*u-boot*" -print; find /etc -maxdepth 3 -type f -iname "*fw_env*" -print; ls -la /boot; ls -la /rom/boot; ls -l /dev/mmcblk0boot0 /dev/mmcblk0boot1; cat /sys/class/block/mmcblk0boot0/force_ro; cat /sys/class/block/mmcblk0boot1/force_ro; blkid /dev/mmcblk0p1 /dev/mmcblk0p2 /dev/mmcblk0p3 /dev/mmcblk0p4 /dev/mmcblk0p5 /dev/mmcblk0p6 /dev/mmcblk0p7 /dev/mmcblk0p8 /dev/mmcblk0p9 /dev/mmcblk0p10'
```

The read scripts contain `dd` and write operations, but were never executed.

### 19. Display/touch/camera/bus devices and a local config include

```sh
ssh -o BatchMode=yes <printer-host> 'cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq; cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq; cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq; cat /proc/bus/input/devices; ls -l /dev/input /dev/fb* /dev/video* /dev/v4l/by-id /dev/i2c* /dev/spidev*; cat /sys/class/graphics/fb0/modes; cat /sys/class/graphics/fb0/virtual_size; ls -l /usr/bin/master-server /usr/bin/app-server /usr/bin/display-server /usr/bin/web-server /usr/bin/upgrade-server /usr/bin/cx_ai_middleware /usr/bin/webrtc /usr/bin/cam_app /usr/bin/mjpg_streamer /usr/bin/wipe_data; cat <local-config-include>'
```

### 20. Reference-only modules and remaining service state

```sh
ssh -o BatchMode=yes <printer-host> 'for f in /usr/share/klipper/klippy/extras/*.py; do b=$(basename $f); if [ ! -e <local-klipper-tree>/klippy/extras/$b ]; then echo stock-only:$b; fi; done; for f in /usr/share/klipper/klippy/*.py; do b=$(basename $f); if [ ! -e <local-klipper-tree>/klippy/$b ]; then echo stock-core-only:$b; fi; done; grep -m 5 -Ei "git version|start printer at|software_version" <local-klipper-log>; <local-klipper-env>/bin/python --version; cat /etc/init.d/S99start_app; ls -ld <local-alternate-web-ui> <local-web-ui>; cat /etc/init.d/<local-integration-service>; cat /etc/init.d/<local-package-service>'
```

## Unsuccessful connection setup attempts

Several connection attempts made before public-key setup did not execute a remote
payload. Their workstation-specific configuration paths and authentication details
are intentionally omitted from the public log. All successful calls above used
`BatchMode=yes` and required no interactive input.
