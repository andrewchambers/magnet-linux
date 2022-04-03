exec >&2

redo-ifchange seed.tar.gz
sha256sum --quiet -c files
cp seed.tar.gz "$3"
