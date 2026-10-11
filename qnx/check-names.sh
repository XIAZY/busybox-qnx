#!/bin/sh
# Checks that a program asks the loader only for names that the system it
# is meant for has.
#
#   qnx/check-names.sh PROGRAM ALLOWED...
#
# Each ALLOWED is a shared library, or a text file with one name a line
# (qnx/qnx650-names/*.txt: what QNX 6.5.0's libc, libm and libsocket
# export). The program's needs are its undefined dynamic symbols and the
# data symbols it copies from a library (COPY relocations), which a list of
# undefined symbols does not show. Any name outside the allowed ones is
# printed, and the exit status is 1: the program would not load.
#
# A program linked against BlackBerry 10's libraries can pick up names
# that QNX 6.5 lacks without anyone noticing; this is where it shows.
# READELF names the readelf to use (default: readelf).
set -eu

readelf=${READELF:-readelf}
program=$1
shift

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The dynamic symbols of an ELF file: "UND name" or "DEF name" a line.
symbols() {
    # The name is the last column and the section the one before it; the
    # type column can be more than one word ("<OS specific>: 10").
    "$readelf" --dyn-syms -W "$1" | awk '
        $1 ~ /^[0-9]+:$/ && NF >= 8 {
            name = $NF; sub(/@.*/, "", name)
            print ($(NF-1) == "UND" ? "UND" : "DEF"), name
        }'
}

for allowed in "$@"; do
    if [ "$(head -c 4 "$allowed" | od -An -c | tr -d ' ')" = '177ELF' ]; then
        symbols "$allowed" | awk '$1 == "DEF" { print $2 }'
    else
        cat "$allowed"
    fi
done | sort -u > "$work/allowed"

{
    symbols "$program" | awk '$1 == "UND" { print $2 }'
    "$readelf" -r -W "$program" | awk '$3 ~ /_COPY$/ { name = $5; sub(/@.*/, "", name); print name }'
} | sort -u > "$work/needed"

comm -23 "$work/needed" "$work/allowed" > "$work/missing"
if [ -s "$work/missing" ]; then
    echo "error: $program needs names that are not allowed:" >&2
    sed 's/^/    /' "$work/missing" >&2
    exit 1
fi
echo "$program: $(wc -l < "$work/needed" | tr -d ' ') names needed, all allowed"
