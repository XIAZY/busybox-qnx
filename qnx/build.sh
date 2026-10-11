#!/bin/sh
# Builds BusyBox for QNX from a clean checkout: ./busybox, a stripped
# program linked against the system's own libraries.
#
#   qnx/build.sh [bb10|qnx65]
#
# bb10 (the default) is BlackBerry 10, 32-bit ARM; qnx65 is QNX 6.5 on x86.
# Both are built from the same source with the same configuration
# (configs/qnx_defconfig) and the BlackBerry 10 toolchain, which must be on
# the PATH: its C compiler driver for the target (bb10-cc or qnx65-cc) and
# binutils (GNU for ARM, LLVM's for x86); besides a C compiler for the build
# machine (cc, or name one in HOSTCC), make, python3, and git or
# SOURCE_DATE_EPOCH set. See qnx/README.md.
set -eu

target=${1:-bb10}
cd "$(dirname "$0")/.."
qnx=$(pwd)/qnx
sdk=${QNX_TARGET:-/opt/bb10-sdk/target/qnx6}

case $target in
bb10)
    prefix=arm-unknown-nto-qnx6.5.0eabi-
    # qnx/cc is bb10-cc with the link step rearranged; which see. LD is
    # named because BusyBox's default, "$(CC) -nostdlib", is used to join
    # object files ("-r"), and the driver would link a whole program there.
    cc=$qnx/cc
    ld=${prefix}ld
    tools="AR=${prefix}ar NM=${prefix}nm STRIP=${prefix}strip OBJCOPY=${prefix}objcopy OBJDUMP=${prefix}objdump"
    needs="bb10-cc ${prefix}ld ${prefix}ar ${prefix}strip ${prefix}readelf"
    ;;
qnx65)
    # The driver's own defaults, said here so that the file never needs
    # more than a 486 whatever the driver comes to default to.
    cc="qnx65-cc -march=i486 -mno-sse"
    ld="ld.lld -m elf_i386"
    tools="AR=llvm-ar NM=llvm-nm STRIP=llvm-strip OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump"
    needs="qnx65-cc ld.lld llvm-ar llvm-strip qnx65-check-names"
    ;;
*)
    echo "usage: qnx/build.sh [bb10|qnx65]" >&2
    exit 2
    ;;
esac

for tool in $needs python3 make; do
    command -v "$tool" >/dev/null || { echo "error: $tool is not on the PATH (see qnx/README.md)" >&2; exit 1; }
done
# BusyBox's build scripts need bzip2; a stand-in if the machine has none.
command -v bzip2 >/dev/null || PATH=$qnx/hostbin:$PATH
export PATH

# BusyBox writes its build time into the program. So that the same source
# gives the same file, byte for byte, the time is that of the commit.
# Where the build runs without git (the toolchain's container image), it is
# passed in: SOURCE_DATE_EPOCH=$(git log -1 --format=%ct).
if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
    SOURCE_DATE_EPOCH=$(git log -1 --format=%ct) || {
        echo "error: set SOURCE_DATE_EPOCH to the commit's time (git log -1 --format=%ct)" >&2; exit 1; }
fi
export SOURCE_DATE_EPOCH
# The time is written out in the build machine's time zone.
export TZ=UTC

hostcc=${HOSTCC:-cc}
jobs=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)

# Nothing of an earlier build, which may have been for the other target.
make HOSTCC="$hostcc" mrproper >/dev/null
make HOSTCC="$hostcc" qnx_defconfig
# shellcheck disable=SC2086
make HOSTCC="$hostcc" CC="$cc" LD="$ld" $tools -j"$jobs"

# The program may ask the loader only for names that the system has.
case $target in
bb10)
    # Against the SDK's own libraries for the phone.
    READELF=${prefix}readelf "$qnx/check-names.sh" busybox \
        "$sdk/armle-v7/lib/libc.so.3" "$sdk/armle-v7/lib/libm.so.2" \
        "$sdk/armle-v7/lib/libsocket.so.3" "$sdk/armle-v7/usr/lib/libbps.so.3"
    ;;
qnx65)
    # Against what QNX 6.5.0's libraries export: the SDK's x86 libraries,
    # which the program is linked against, have more. The toolchain has the
    # lists and the check (the same script as qnx/check-names.sh).
    names=/opt/bb10-toolchain/share/qnx65-symbols
    qnx65-check-names busybox "$names/libc.so.3.txt" "$names/libm.so.2.txt" "$names/libsocket.so.3.txt"
    ;;
esac
ls -l busybox
