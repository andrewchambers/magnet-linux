set -u
set -o pipefail

filename="$(basename "$1")"
pkgdir="$(dirname "$1")"

case $filename in
  run-closure)
    redo-ifchange "$pkgdir/run-deps"
    deps="$(cat "$pkgdir/run-deps")"

    for dep in $deps; do
      if ! test -d "$pkgdir/$dep"; then
        echo "run dependency $dep of $pkgdir does not exist" >&2
        exit 1
      fi
      echo "$pkgdir/$dep/run-closure"
    done | xargs -r redo-ifchange

    for dep in $deps; do
      echo "$pkgdir/$dep"
      for closed_over in $(cat "$pkgdir/$dep/run-closure"); do
        echo "$dep/$closed_over"
      done
    done | xargs -r realpath --relative-to "$pkgdir" | sort -u >"$3"
    ;;
  build-closure)
    redo-ifchange "$pkgdir/build-deps"
    deps="$(cat "$pkgdir/build-deps")"

    for dep in $deps; do
      if ! test -d "$pkgdir/$dep"; then
        echo "build dependency $dep of $pkgdir does not exist" >&2
        exit 1
      fi
      echo "$pkgdir/$dep/run-closure"
    done | xargs -r redo-ifchange

    for dep in $deps; do
      echo "$pkgdir/$dep"
      for closed_over in $(cat "$pkgdir/$dep/run-closure"); do
        echo "$pkgdir/$dep/$closed_over"
      done
    done | xargs -r realpath --relative-to "$pkgdir" | sort -u >"$3"
    ;;
  pkg-hash)
    redo-ifchange \
      "$pkgdir/build" \
      "$pkgdir/build-closure"

    build_closure="$(cat "$pkgdir/build-closure")"
    for closed_over in $build_closure; do
      echo "$pkgdir/$closed_over/pkg-hash"
    done | xargs -r redo-ifchange
    (
      echo "v1"
      echo "build"
      cat "$pkgdir/build"
      echo "build-closure"
      for closed_over in $build_closure; do
        echo "$pkgdir/$closed_over/pkg-hash"
      done | xargs -r cat
    ) | sha256sum | cut -c 1-64 >"$3"
    ;;
  run-deps | build-deps)
    touch "$3"
    ;;

  pkg.tar.zst)
    redo-ifchange \
      "$pkgdir/build" \
      "$pkgdir/build-closure"

    for closed_over in $(cat "$pkgdir/build-closure"); do
      echo "$pkgdir/$closed_over/pkg.tar.zstd"
    done | xargs -r redo-ifchange
    ;;
  *)
    echo "don't know how to build $1" >&2
    exit 1
    ;;
esac
