# BusyBox for BlackBerry 10

This branch (`qnx`) is BusyBox 1.38.0 with the changes it needs to build
for and run on BlackBerry 10: QNX 8 on 32-bit ARM. The result is one
program of about 650 KB with 141 tools, linked against the phone's own
libraries (`libc`, `libm`, `libsocket`, `libbps`).

BusyBox does not support QNX itself. Every change here is inside
`#if defined(__QNX__)` or adds a case for it, one commit per cause; the
commit messages give the error each one answers.

## Building

    qnx/build.sh

It needs on the `PATH`:

- `bb10-cc`, the C compiler driver of the BlackBerry 10 toolchain (clang
  for the compiling, GNU ld for QNX for the linking, with the BlackBerry 10
  SDK's headers and libraries);
- the GNU binutils for `arm-unknown-nto-qnx6.5.0eabi`;
- a C compiler for the build machine (`cc`, or name one in `HOSTCC`),
  `make` and `python3`.

The container image `ghcr.io/xiazy/blackberry10-toolchain` has all of
them. From a clean checkout:

    docker run --rm -v "$PWD:/src" -w /src --user "$(id -u):$(id -g)" \
        ghcr.io/xiazy/blackberry10-toolchain:latest qnx/build.sh

The script configures with `configs/bb10_defconfig` and leaves the stripped
program in `./busybox`.

Two helpers stand between BusyBox's build and the toolchain:

- `qnx/cc` is the compiler the build is given. It passes everything to
  `bb10-cc` and only rearranges the link step; its header says why.
- `qnx/hostbin/bzip2` stands in for `bzip2`, which BusyBox's build scripts
  use, on a build machine that has none.

## Checking a build

    busybox ash check.sh /path/to/busybox        # on the device
    busybox ash check.sh /path/to/busybox net    # with http and https too

`qnx/check.sh` runs about a hundred small commands, one or more for most
tools, and compares what comes out. The file has to be named `busybox`.
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
certificate**; it says so on each use.

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

- `touch -h` has no effect: times are set with `utimes()`, which always
  follows a symbolic link.
- `stat` and `touch -r` work in whole seconds.
- A system call that a signal interrupts is not restarted by the system
  (QNX has no `SA_RESTART`); BusyBox's own retrying covers it.
- BusyBox finds its own program through `/proc/self/exe`, which QNX does
  not have. So `ash` does not run the tools by itself; they are found on
  the `PATH`, by links made with `busybox --install -s DIR`.
