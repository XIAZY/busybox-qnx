# BusyBox for QNX 6.5 and BlackBerry 10

This is BusyBox 1.38.0 with the changes it needs to build for and run on
QNX: QNX 6.5.0 on x86, and BlackBerry 10 (QNX 8 on 32-bit ARM). One source
for both; the result is one program of 450 to 650 KB with 141 tools,
linked against the system's own libraries (`libc`, `libm`, `libsocket`,
and `libbps` on the phone).

BusyBox does not support QNX itself. Every change here is inside
`#if defined(__QNX__)` or adds a case for it, one commit per cause; the
commit messages give the error each one answers.

**QNX 6.5 is the baseline.** BlackBerry 10 is built on it and its C
library has more: 222 names that 6.5's lacks. Each program is built
against its own system's SDK, and the source uses nothing that 6.5 does
not have: where BusyBox needs one of those names it brings its own, on
both systems (see "What QNX 6.5 lacks"). After each build
`qnx/check-names.sh` confirms that the program asks the loader only for
names its system's libraries have.

## Building

    qnx/build.sh bb10       # BlackBerry 10, 32-bit ARM (the default)
    qnx/build.sh qnx65      # QNX 6.5 on x86

Both use the same configuration (`configs/qnx_defconfig`) and leave the
stripped program in `./busybox`; every build starts clean. They need on the
`PATH`:

- for `bb10`: `bb10-cc`, the C compiler driver for BlackBerry 10 (clang
  for the compiling, GNU ld for QNX for the linking, with the BlackBerry 10
  SDK's headers and libraries), and the GNU binutils for
  `arm-unknown-nto-qnx6.5.0eabi`;
- for `qnx65`: `qnx65-cc`, the driver for QNX 6.5 (clang and lld, with QNX
  SDP 6.5.0's own headers, libraries and gcc support files), LLVM's
  binutils (`llvm-ar`, `llvm-readelf` and the rest);
- a C compiler for the build machine (`cc`, or name one in `HOSTCC`),
  `make` and `python3`.

The container image `ghcr.io/xiazy/blackberry10-toolchain` has all of
them (`qnx65-cc` from the version that added the QNX 6.5 target on). From a
clean checkout, with the version of the image that the released files are
built with:

    docker run --rm -v "$PWD:/src" -w /src --user "$(id -u):$(id -g)" \
        -e SOURCE_DATE_EPOCH="$(git log -1 --format=%ct)" \
        ghcr.io/xiazy/blackberry10-toolchain@sha256:e56e8572589d46d86f7be108d6d14cfe20a5097c46ac9c655edd042eecd437be \
        qnx/build.sh bb10

BusyBox writes its build time into the program; `SOURCE_DATE_EPOCH` sets it
to the time of the commit, so the same commit built with the same image
gives the same file, byte for byte. `.github/workflows/build.yml` builds
every push this way, and a tag `v*` publishes that build as a release with
its checksum, so a released file can be rebuilt and compared.

Two helpers stand between BusyBox's build and the toolchain:

- `qnx/cc` is the compiler the build is given. It passes everything to
  `bb10-cc` and only rearranges the link step; its header says why.
- `qnx/hostbin/bzip2` stands in for `bzip2`, which BusyBox's build scripts
  use, on a build machine that has none.

## Checking a build

    busybox ash check.sh /path/to/busybox        # on the device
    busybox ash check.sh /path/to/busybox net    # with http and https too

`qnx/check.sh` runs about 110 small commands, one or more for most
tools, and compares what comes out. It is the same on both systems. The file has to be named `busybox`.
Checks that need symbolic links, permissions or named pipes are skipped in
a directory that has none, such as a FAT memory card.

## The tools that are in

    [ [[ ar ash awk base32 base64 basename bc bunzip2 bzcat bzip2 cal cat
    chgrp chmod chown cksum clear cmp comm cp cpio cut date dc dd diff
    dirname dos2unix du echo ed egrep env expand expr factor false fgrep
    find fold fsync ftpget ftpput grep gunzip gzip hd head hexdump hostname
    id install kill less link ln logname ls lzma md5sum mkdir mkfifo mknod
    mktemp more mv nc nice nl nohup nproc od paste patch printenv printf
    pwd readlink realpath renice reset rev rm rmdir sed seq sh sha1sum
    sha256sum sha3sum sha512sum shred shuf sleep sort split stat strings
    stty sum sync tac tail tar tee telnet test time timeout touch tr tree
    true truncate tsort tty uname unexpand uniq unix2dos unlink unlzma unxz
    unzip usleep uudecode uuencode vi watch wc wget which whoami xargs xxd
    xz xzcat yes zcat

and `busybox` itself, with `--list` and `--install`.

`ash` has line editing, history, tab completion and job control. `wget`
does https with BusyBox's own TLS, which **does not check the server's
certificate**; it says so on each use. It never hands https to an
`openssl` program on the machine, as BusyBox otherwise would: QNX 6.5's is
OpenSSL 0.9.8 from 2010, which no server accepts any more.

## The tools that are out, and why

| Tool | Why |
|---|---|
| `ps`, `pidof`, `pgrep`, `pkill`, `killall`, `top` | They build, but they read Linux's `/proc`, which QNX lays out differently: on the phone they print nothing or stop with an error. A tool that gives wrong answers is worse than none. |
| `who`, `w`, `users` | They read the login records (utmp), which the phone does not keep. |
| `free`, `uptime` | Linux's `sysinfo()`. |
| `df` | `<mntent.h>` and the mount table as Linux keeps it. |
| `ping` | Written against Linux's ICMP headers (`struct iphdr`, `ICMP_DEST_UNREACH` and others). |
| `nslookup` | Written against glibc's resolver internals (`ns_parserr`, `_res._u._ext.nsaddrs`). |
| `tftp` | `<syslog.h>`, which the SDK does not have. |
| `hostid` | `gethostid()` is not in the C library. |
| everything else of BusyBox | Not tried: `mount`, `init`, the module, console and network set-up tools and the like are for a Linux system, not for a shell on a phone. |

The phone has its own `ps`, `df`, `uptime` and `ping`.

Features switched off inside tools that are in: shadow passwords and login
records, `sync -f` (`syncfs()`), `stat -f` (`statfs()`), `sendfile()`.

## What differs from BusyBox on Linux

- **Options are parsed by BusyBox itself** (`libbb/qnx_getopt.c`, from musl
  libc): QNX 6.5 has no `getopt_long()`. As with musl, a tool that reads
  its options with plain `getopt()` (`head`, `od`, `awk`, `unzip`) wants
  them before the other arguments; the rest take them anywhere
  (`grep PATTERN FILE -c`).
- `date +%s` is done by `date`: QNX's `strftime()` has no `%s`.
- `touch -h` has no effect: times are set with `utimes()`, which always
  follows a symbolic link.
- `stat` and `touch -r` work in whole seconds.
- A system call that a signal interrupts is not restarted by the system
  (QNX has no `SA_RESTART`); BusyBox's own retrying covers it.
- A server socket on "any address" (`nc -l`) takes IPv4 and IPv6 peers, as
  on Linux; QNX's default would be IPv6 only.
- BusyBox finds its own program through `/proc/self/exe`, which QNX does
  not have. So `ash` does not run the tools by itself; they are found on
  the `PATH`, by links made with `busybox --install -s DIR`.

## What QNX 6.5 lacks and BusyBox brings

| Name | What is used instead |
|---|---|
| `getopt_long` | `bb_getopt_long` and `bb_getopt`, from musl |
| `timegm`, `strnlen` | BusyBox's own, in `libbb/platform.c` |
| `mkdtemp`, `strcasestr` | BusyBox's own, as on other systems without them |
| `__h_errno` (BlackBerry 10's `h_errno` is a call of it) | the plain variable `h_errno`, which both have |
| `<getopt.h>`, `O_NOFOLLOW` | `struct option` is defined where the header is missing; `unzip` opens files without `O_NOFOLLOW` on 6.5 |

Two things are done on every QNX build, though it is x86 that needs them:
BusyBox's replacement functions go by names of their own (`bb_strndup`,
`bb_stpcpy`, ...), because of the register calling convention BusyBox uses
on x86; and the byte swaps are the compiler's, because the ones in QNX's
headers are x86 assembly that clang does not take.

## Licences

BusyBox is under the GNU General Public License, version 2 (`LICENSE`).
`libbb/qnx_getopt.c` is from musl libc, under the MIT licence; its notice
is in the file. `qnx/check-names.sh` is not part of BusyBox and is under
the MIT licence too, so that other projects can use it as it is. 

The programs also contain what the toolchain links in: for BlackBerry 10
a few helper functions of LLVM's compiler-rt (Apache License 2.0 with LLVM
exceptions); for QNX 6.5 gcc's start-up objects and helper functions
(`crtbegin`, `libgcc`; GPL with the GCC runtime library exception); and
for both the few functions that are only in the SDK's static C library
(`regcomp`, `scandir`, `popen`, `strptime`, `getlogin`).
