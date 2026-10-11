#!/bin/sh
# Builds BusyBox for BlackBerry 10 from a clean checkout: ./busybox, a
# stripped 32-bit ARM QNX program linked against the phone's own libraries.
#
# Needs on the PATH: bb10-cc (the BlackBerry 10 toolchain's C compiler
# driver), the GNU binutils for arm-unknown-nto-qnx6.5.0eabi, a C compiler
# for the build machine (cc, or name one in HOSTCC), make, python3 and git
# (or SOURCE_DATE_EPOCH set). See qnx/README.md.
set -eu

cd "$(dirname "$0")/.."
qnx=$(pwd)/qnx
prefix=arm-unknown-nto-qnx6.5.0eabi-

for tool in bb10-cc ${prefix}ld ${prefix}ar ${prefix}strip python3 make; do
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

hostcc=${HOSTCC:-cc}
jobs=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)

make HOSTCC="$hostcc" bb10_defconfig
# CC is qnx/cc, which see. LD is named because BusyBox's default, "$(CC)
# -nostdlib", is used to join object files ("-r"), and bb10-cc would link a
# whole program there.
make HOSTCC="$hostcc" CC="$qnx/cc" LD=${prefix}ld -j"$jobs"
ls -l busybox
