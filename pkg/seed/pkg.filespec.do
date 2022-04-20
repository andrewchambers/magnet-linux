exec >&2

redo-ifchange seed.tar.gz
sha256sum --quiet -c files
rm -rf pkg
mkdir pkg
gzip -d < seed.tar.gz | tar -C pkg -xf -
filespec-fromdirs -r pkg pkg \
 | filespec-b3sum -C pkg > "$3"
