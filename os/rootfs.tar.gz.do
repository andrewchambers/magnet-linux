set -eu
set -o pipefail
IFS="
"
exec >&2

redo-ifchange $(find etc) \
  rootfs.filespec \
  pkg.list

redo-ifchange $(printf "%s/pkg.filespec\n" $(cat pkg.list))

closure=$(
	realpath --relative-to "." $(
		for pkg in $(cat pkg.list)
		do
			echo "$pkg"
			for dep in $(cat $pkg/run-closure); do
				echo "$pkg/$dep"
			done
		done
	) | sort -u
)

if test -e staging
then
	chmod -R 700 staging
	rm -rf staging	
fi

mkdir staging
cp -r etc staging

for pkg in $closure
do
	tar -C staging -xf "$pkg/pkg.tar.gz"
done

filespec-sort -p -u \
  rootfs.filespec \
  $(printf "%s/pkg.filespec\n" $closure) \
  | filespec-b3sum -C staging -c \
  | filespec-tar -C staging \
  | gzip > "$3"
