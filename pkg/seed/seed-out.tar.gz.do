#!/bin/sh
set -eux

exec >&2
out="$(realpath $3)"
IFS="
"

pkgs="
../gcc
../binutils
../oksh
../coreutils
../findutils
../diffutils
../patch
../grep
../sed
../tar
../xz
../gzip
../make
../musl
../linux-headers
"

filespecs=$(printf "%s/pkg.filespec\n" $pkgs)

redo-ifchange $filespecs
# Check for duplicate files.
fspec-sort -u $filespecs > /dev/null

if test -e ./seed-out.tmp
then
  chmod -R 700 ./seed-out.tmp
  rm -rf ./seed-out.tmp
fi

mkdir seed-out.tmp

for pkg in $pkgs
do
  tar -C ./seed-out.tmp -xf "$pkg/pkg.tar.gz"
done

fspec-fromdir -r ./seed-out.tmp ./seed-out.tmp \
  | fspec-tar -C ./seed-out.tmp \
  | gzip > "$3"

chmod -R 700 ./seed-out.tmp
rm -rf ./seed-out.tmp