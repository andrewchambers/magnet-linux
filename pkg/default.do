set -eu
set -o pipefail
exec >&2
IFS="
"
scriptdir="$PWD"
filename="$(basename "$1")"
pkgdir="$(dirname "$1")"
out="$(readlink -f "$3")"

cd "$pkgdir"

case $filename in
  run-closure)
    redo-ifchange run-deps
    deps="$(cat run-deps)"

    for dep in $deps; do
      echo "$dep/run-closure"
    done | xargs -r redo-ifchange

    for dep in $deps; do
      echo "$dep"
      for closed_over in $(cat "$dep/run-closure"); do
        echo "$dep/$closed_over"
      done
    done | xargs -r realpath --relative-to "." | sort -u > "$out"
    ;;
  build-closure)
    redo-ifchange build-deps
    deps="$(cat build-deps)"

    for dep in $deps; do
      if ! test -d "$dep"; then
        echo "build dependency $dep of $pkgdir does not exist"
        exit 1
      fi
      echo "$dep/run-closure"
    done | xargs -r redo-ifchange

    for dep in $deps; do
      echo "$dep"
      for closed_over in $(cat "$dep/run-closure"); do
        echo "$dep/$closed_over"
      done
    done | xargs -r realpath --relative-to "." | sort -u > "$out"
    ;;
  pkg-hash)
    redo-ifchange \
      build \
      build-closure

    build_closure="$(cat build-closure)"
    for closed_over in $build_closure; do
      echo "$closed_over/pkg-hash"
    done | xargs -r redo-ifchange
    (
      echo subst-hash
      echo files
      cat files | sort
      echo build
      cat build
      echo build-closure
      for closed_over in $build_closure; do
        echo "$closed_over/pkg-hash"
      done | xargs -r cat
    ) | sha256sum | cut -c 1-64 >"$3"
    ;;
  pkg.tar.zst)
    redo-ifchange \
      build \
      build-closure \
      files

    if grep -q -e "^/" -e "\.\./" files
    then
      echo "$pkgdir/files list must not contain ../ or ^/"
      exit 1
    fi
      
    cut -f 2- -d " " < files | xargs -r redo-ifchange

    sha256sum --strict -c files

    for closed_over in $(cat build-closure); do
      echo "$closed_over/pkg.tar.zstd"
    done | xargs -r redo-ifchange
    
    exit 123
    ;;
  run-deps | build-deps | files)
    touch "$out"
    ;;
  build)
    echo "$1 is a mandatory file."
    exit 1
    ;;
  *)
    redo-ifchange files
    
    hash=""
    found=false
    for line in $(cat files)
    do
      hash=$(echo "$line" | cut -f -1 -d ' ')
      name=$(echo "$line" | cut -f 2- -d ' ')
      if test "$filename" = "$name"
      then
        found=true
        break
      fi 
    done

    if ! test "$found" = true
    then
      echo "don't know how to build $1 and it is not in the files list"
      exit 1
    fi

    found=false
    mirror_dir="${REDO_LINUX_MIRROR_DIR:-$scriptdir/../mirrors}"
    mirrors=$(find "$mirror_dir" -type f | xargs -r cat | grep -e "^$hash" | sort)
    for mirror in $mirrors
    do
      url=$(echo "$mirror" | cut -f 3- -d ' ')
      echo "downloading $url..."
      curl -s -L "$url" -o "$out"
      actual_hash=$(sha256sum "$out" | cut -c 1-64)
      if test "$hash" = "$actual_hash"
      then
        found=true
        break
      fi
      echo "mirror $url failed hash check, trying next"
    done

    if ! test "$found" = true
    then
      echo "all mirrors failed, unable to download $pkgdir/$filename"
      exit 1
    fi

    ;;
esac
