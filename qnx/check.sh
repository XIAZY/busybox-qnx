#!/bin/sh
# A run check of a BusyBox build, for the device it was built for.
#
#   busybox ash check.sh /path/to/busybox [net]
#
# The file must be named "busybox" (or start with it): BusyBox goes by its
# own name. Run it in a directory that can be written to; it works in a
# subdirectory "w" there and removes it. With "net" as the second argument
# it also fetches a page over http and https (CHECK_HOST, default
# www.google.com).
#
# Each line is one tool: "ok", "FAIL" with what came out, or "skip". The
# checks marked fs need a filesystem with symbolic links, permissions and
# named pipes, and are skipped where the directory has none (a FAT card).
B=$1
NET=${2:-}
HOST=${CHECK_HOST:-www.google.com}
D=$(pwd)
pass=0; fail=0; skip=0
t() { # name, expected output, command...
    name=$1; want=$2; shift 2
    got=$("$@" 2>&1); rc=$?
    if [ "$got" = "$want" ]; then pass=$((pass+1)); echo "ok   $name"
    else fail=$((fail+1)); echo "FAIL $name: rc=$rc got=[$(echo "$got" | $B head -c 200)]"; fi
}
r() { # name, command...: must exit 0; its first line is shown
    name=$1; shift
    got=$("$@" 2>&1); rc=$?
    if [ $rc = 0 ]; then pass=$((pass+1)); echo "ok   $name: $(echo "$got" | $B head -n 1 | $B cut -c1-70)"
    else fail=$((fail+1)); echo "FAIL $name: rc=$rc got=[$(echo "$got" | $B head -c 200)]"; fi
}
s() { skip=$((skip+1)); echo "skip $1: $2"; }
$B rm -rf w; $B mkdir w; cd w
$B printf 'banana\napple\ncherry\napple\n' > f
$B seq 1 100 > n

t echo "hi there" $B echo hi there
t printf "a-07" $B printf '%s-%02d' a 7
t cat "banana" $B sh -c "$B cat f | $B head -n 1"
t head "1
2" $B head -n 2 n
t tail "99
100" $B tail -n 2 n
t wc "100" $B sh -c "$B wc -l < n"
t sort "apple
apple
banana
cherry" $B sort f
t uniq "apple
banana
cherry" $B sh -c "$B sort f | $B uniq"
t tr "BANANA" $B sh -c "$B head -n1 f | $B tr a-z A-Z"
t cut "ban" $B sh -c "$B head -n1 f | $B cut -c1-3"
t sed "bXnXnX" $B sh -c "$B head -n1 f | $B sed s/a/X/g"
t awk "5050" $B awk '{s+=$1} END{print s}' n
t awk-rand "ok" $B awk 'BEGIN{srand(1); x=rand(); if (x>=0 && x<1) print "ok"}'
t grep "apple
apple" $B grep apple f
t grep-c "2" $B grep -c apple f
t egrep "banana
cherry" $B egrep 'ban|che' f
t tac "apple" $B sh -c "$B tac f | $B head -n1"
t rev "ananab" $B sh -c "$B head -n1 f | $B rev"
t nl "     1	banana" $B sh -c "$B nl f | $B head -n1"
t paste "banana apple cherry apple" $B paste -s -d' ' f
t fold "ban
ana" $B sh -c "$B head -n1 f | $B fold -w3"
t expr "7" $B expr 3 + 4
t bc "42" $B sh -c "echo '6*7' | $B bc"
t dc "42" $B sh -c "echo '6 7 * p' | $B dc"
t factor "42: 2 3 7" $B factor 42
t seq "1 3 5" $B sh -c "$B seq 1 2 5 | $B paste -s -d' '"
t basename "c.txt" $B basename /a/b/c.txt
t dirname "/a/b" $B dirname /a/b/c.txt
t test "yes" $B sh -c "$B test -f f && echo yes"
t true-false "1" $B sh -c "$B true; $B false; echo \$?"
t md5sum "5eb63bbbe01eeed093cb22bb8f5acdc3" $B sh -c "$B printf 'hello world' | $B md5sum | $B cut -d' ' -f1"
t sha1sum "2aae6c35c94fcfb415dbe95f408b9ce91ee846ed" $B sh -c "$B printf 'hello world' | $B sha1sum | $B cut -d' ' -f1"
t sha256sum "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9" $B sh -c "$B printf 'hello world' | $B sha256sum | $B cut -d' ' -f1"
t base64 "aGVsbG8=" $B sh -c "$B printf hello | $B base64"
t base64-d "hello" $B sh -c "echo aGVsbG8= | $B base64 -d"
t od "0000000 150 151" $B sh -c "$B printf hi | $B od -b | $B head -n1 | $B tr -s ' '"
t hexdump "00000000  68 69                                             |hi|" $B sh -c "$B printf hi | $B hexdump -C | $B head -n1"
t xxd "00000000: 6869                                     hi" $B sh -c "$B printf hi | $B xxd"
t cmp "0" $B sh -c "$B cmp f f; echo \$?"
t diff "--- f
+++ g
@@ -1,4 +1,4 @@
-banana
+BANANA
 apple
 cherry
 apple" $B sh -c "$B sed '1s/.*/BANANA/' f > g; $B diff -L f -L g -u f g"
t patch "BANANA" $B sh -c "$B diff -u f g > p; $B cp f h; $B patch h < p >/dev/null; $B head -n1 h"
t cp-mv-rm "moved gone" $B sh -c "$B cp f c1; $B mv c1 c2; test -f c2 && echo -n 'moved '; $B rm c2; test -f c2 || echo gone"
t mkdir-rmdir "d gone" $B sh -c "$B mkdir -p d/e; test -d d/e && echo -n 'd '; $B rmdir d/e d; test -d d || echo gone"
t ls "f
g" $B sh -c "$B ls | $B grep -x '[fg]'"
r ls-l $B ls -l f
t find "./f" $B find . -name f
t find-exec "banana" $B sh -c "$B find . -name f -exec $B head -n1 {} \;"
t xargs "banana apple cherry apple" $B sh -c "$B cat f | $B xargs $B echo"
t touch-stat "1000000000" $B sh -c "$B touch -d @1000000000 tt && $B stat -c %Y tt"
t touch-new "yes" $B sh -c "$B touch newf && test -f newf && echo yes"
t du "yes" $B sh -c "$B du -s . >/dev/null && echo yes"
t split "aa ab" $B sh -c "$B split -l 50 n s_ && $B ls s_* | $B sed s/s_// | $B paste -s -d' '"
t tar "banana" $B sh -c "$B tar cf a.tar f g && $B mkdir x && $B tar xf a.tar -C x && $B head -n1 x/f"
t gzip "banana" $B sh -c "$B cp f z1 && $B gzip z1 && $B zcat z1.gz | $B head -n1"
t gunzip "yes" $B sh -c "$B gunzip z1.gz && $B cmp f z1 && echo yes"
t bzip2 "banana" $B sh -c "$B cp f z2 && $B bzip2 z2 && $B bzcat z2.bz2 | $B head -n1"
t xz-d "yes" $B sh -c "$B unxz --help 2>&1 | $B grep -q Usage && echo yes"
t cpio "f" $B sh -c "echo f | $B cpio -o -H newc 2>/dev/null | $B cpio -t 2>/dev/null"
t date "2001-09-09" $B date -u -d @1000000000 +%Y-%m-%d
r date-now $B date
t env "X=1" $B sh -c "$B env -i X=1 $B env"
t printenv "v" $B sh -c "Q=v $B printenv Q"
r id $B id
r whoami $B whoami
r uname $B uname -a
r hostname $B hostname
r pwd $B pwd
r tty $B sh -c "$B tty; true"
r nproc $B nproc
r cal $B cal 1 2000
t mktemp "yes" $B sh -c "f=\$($B mktemp -p .) && test -f \$f && echo yes"
t realpath "$D/w/f" $B realpath f
t which "yes" $B sh -c "$B which sh >/dev/null && echo yes"
t yes "y
y" $B sh -c "$B yes | $B head -n2"
t tee "hi" $B sh -c "echo hi | $B tee tf >/dev/null; $B cat tf"
t dd "ban" $B sh -c "$B dd if=f bs=1 count=3 2>/dev/null"
t strings "banana" $B sh -c "$B strings f | $B head -n1"
t tree "yes" $B sh -c "$B tree x >/dev/null && echo yes"
t ed "BANANA" $B sh -c "$B printf '1p\nq\n' | $B ed g 2>/dev/null | $B tail -n1"
t less "banana" $B sh -c "$B less f | $B head -n1"
t more "banana" $B sh -c "$B more f | $B head -n1"
t vi "yes" $B sh -c "$B vi -h 2>&1 | $B grep -qi usage && echo yes"
t ash "ok 3" $B ash -c 'f() { echo "ok $((1+2))"; }; f'
t ash-pipe-loop "6" $B ash -c 's=0; for i in 1 2 3; do s=$((s+i)); done; echo $s'
t ash-subst "cherry" $B ash -c 'x=$(sed -n 3p f); echo ${x}'
t ash-bg-wait "done" $B ash -c 'sleep 0.1 & wait; echo done'
t ash-trap "caught" $B ash -c 'trap "echo caught" USR1; kill -USR1 $$; true'
t kill "yes" $B sh -c "$B sleep 30 & p=\$!; $B kill \$p && echo yes"
r stty $B sh -c "$B stty -a </dev/null; true"
t sleep-fraction "yes" $B sh -c "$B sleep 0.2 && echo yes"
t timeout "stopped" $B sh -c "{ $B timeout 1 $B sleep 5 || echo stopped; } 2>/dev/null"
t unzip "yes" $B sh -c "$B unzip 2>&1 | $B grep -qi usage && echo yes"
t busybox-list "yes" $B sh -c "$B --list | $B grep -qx ash && echo yes"
t nc-listen "hello" $B sh -c "(echo hello | $B nc -l -p 45123 >/dev/null 2>&1 &); $B sleep 1; $B nc 127.0.0.1 45123 </dev/null"

# fs: symbolic links, permissions, named pipes, and the tools by their names
if $B ln -s f lnk 2>/dev/null; then
    t fs-readlink "f" $B readlink lnk
    t fs-chmod "600" $B sh -c "$B chmod 600 f && $B stat -c %a f"
    t fs-mkfifo "yes" $B sh -c "$B mkfifo ff && $B test -p ff && echo yes"
    t fs-install "yes" $B sh -c "$B mkdir bin && $B --install -s bin && $B test -L bin/head && echo yes"
    t fs-by-name "banana" $B sh -c "PATH=$D/w/bin head -n 1 f"
    t fs-tar-gz "f
g" $B sh -c "PATH=$D/w/bin:\$PATH; tar czf a.tgz f g && tar tzf a.tgz"
else
    for n in fs-readlink fs-chmod fs-mkfifo fs-install fs-by-name fs-tar-gz; do s $n "no symbolic links in this directory"; done
fi

if [ "$NET" = net ]; then
    t net-wget-http "yes" $B sh -c "$B wget -T 10 -q -O p1 http://$HOST/ && $B test -s p1 && echo yes"
    t net-wget-https "yes" $B sh -c "$B wget -T 10 -q -O p2 https://$HOST/ 2>/dev/null && $B test -s p2 && echo yes"
    t net-nc "HTTP" $B sh -c "$B printf 'HEAD / HTTP/1.0\r\n\r\n' | $B nc $HOST 80 | $B head -c 4"
else
    for n in net-wget-http net-wget-https net-nc; do s $n "run with: check.sh busybox net"; done
fi
cd ..; $B rm -rf w
echo "passed $pass, failed $fail, skipped $skip"
[ $fail = 0 ]
