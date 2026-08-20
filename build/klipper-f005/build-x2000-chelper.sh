#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <klipper-source> <output-c_helper.so>" >&2
    exit 2
fi

source_dir=$1
output=$2
cc=/opt/mips-gcc720-glibc229/bin/mips-linux-gnu-gcc

cd "$source_dir/klippy/chelper"
exec "$cc" -Wall -g -O2 -shared -fPIC \
    -flto -fwhole-program -fno-use-linker-plugin \
    -o "$output" \
    pyhelper.c serialqueue.c stepcompress.c steppersync.c \
    itersolve.c trapq.c pollreactor.c msgblock.c trdispatch.c \
    kin_cartesian.c kin_corexy.c kin_corexz.c kin_delta.c \
    kin_deltesian.c kin_polar.c kin_rotary_delta.c kin_winch.c \
    kin_extruder.c kin_shaper.c kin_idex.c kin_generic.c
