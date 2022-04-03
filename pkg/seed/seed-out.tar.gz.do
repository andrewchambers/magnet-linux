#!/bin/sh
set -eux

exec >&2
out="$(realpath $3)"

tarballs="
../gcc/pkg.tar.gz
../binutils/pkg.tar.gz
../oksh/pkg.tar.gz
../coreutils/pkg.tar.gz
../findutils/pkg.tar.gz
../diffutils/pkg.tar.gz
../patch/pkg.tar.gz
../grep/pkg.tar.gz
../sed/pkg.tar.gz
../tar/pkg.tar.gz
../xz/pkg.tar.gz
../gzip/pkg.tar.gz
../make/pkg.tar.gz
../musl/pkg.tar.gz
../linux-headers/pkg.tar.gz
"

redo-ifchange $tarballs

if test -e ./seed-out.tmp
then
  chmod -R 700 ./seed-out.tmp
  rm -rf ./seed-out.tmp
fi

mkdir seed-out.tmp

for t in $tarballs
do
  tar -C ./seed-out.tmp -xzf $t
done

tar -C ./seed-out.tmp -cvzf "$3" .
chmod -R 700 ./seed-out.tmp/
rm -rf ./seed-out.tmp