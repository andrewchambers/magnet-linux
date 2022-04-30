set -eux
set -o pipefail
exec >&2

redo-ifchange rootfs.filespec

filespec-b3sum -c rootfs.filespec \
| filespec-tar \
| gzip > "$3"

