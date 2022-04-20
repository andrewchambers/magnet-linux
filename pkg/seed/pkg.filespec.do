exec >&2

redo-ifchange seed.tar.gz
sha256sum --quiet -c files
if test -d pkg
then
    chmod -R 700 pkg
    rm -rf pkg
fi
mkdir pkg
gzip -d < seed.tar.gz | tar -C pkg -xf -
filespec-fromdirs -r pkg pkg \
  | filespec-b3sum -C pkg > "$3"
fspec-tar -C pkg < "$3" \
  | gzip > pkg.tar.gz
chmod -R 700 pkg
rm -rf pkg