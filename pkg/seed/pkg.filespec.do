exec >&2

redo-ifchange seed.tar.gz
sha256sum --quiet -c files
test -d .pkgdata && rm -rf .pkgdata
gzip -d < seed.tar.gz \
  | filespec-fromtar -H -d .pkgdata \
  > "$3"
