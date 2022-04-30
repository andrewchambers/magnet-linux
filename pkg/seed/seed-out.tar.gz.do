#!/bin/sh
set -eu

exec >&2
out="$(realpath $3)"

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
../gawk
../gzip
../make
../musl
../linux-headers
"

redo-ifchange $(printf "%s/pkg.filespec\n" $pkgs)

for pkg in $pkgs
do
	awk -v "pkg=$pkg" '
		{ 
			if ($1 == "source:") {
				print("source: " pkg "/" substr($0, 9))
			} else {
				print($0)
			}
		}
	' "$pkg/pkg.filespec" 
done | filespec-sort -u | filespec-tar | gzip > "$3"

