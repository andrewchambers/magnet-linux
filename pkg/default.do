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
umask 022

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
  pkg.filespec)
    redo-ifchange \
      build \
      build-closure \
      run-closure \
      files

    if grep -q -e "^/" -e "\.\./" files
    then
      echo "$pkgdir/files list must not contain ../ or ^/"
      exit 1
    fi
      
    cut -f 2- -d " " < files | xargs -r redo-ifchange

    sha256sum --quiet -c files

    for closed_over in $(cat build-closure run-closure); do
      echo "$closed_over/pkg.filespec"
    done | xargs -r redo-ifchange

    echo "preparing build chroot..."
    
    for dir in pkg chroot
    do
      if test -e "$dir"
      then
        chmod -R 700 "$dir"
        rm -rf "$dir"
      fi
    done

    mkdir \
      pkg \
      chroot \
      chroot/dev \
      chroot/proc \
      chroot/tmp \
      chroot/var \
      chroot/etc \
      chroot/home \
      chroot/home/build \
      chroot/destdir

    # Check for duplicate files in the build environment.
    filespec-sort -u $(printf "%s/pkg.filespec\n" $(cat build-closure)) > /dev/null

    for pkg in $(cat build-closure)
    do
      filespec-tar -C "$pkg/pkg" "$pkg/pkg.filespec" \
        | tar -C ./chroot -xf -
    done

    for file in $(cat files | cut -f 2- -d " " | sed 's/^[[:space:]]*//')
    do
      cp "$file" ./chroot/home/build
    done

    cp build ./chroot/tmp/build
    chmod +x ./chroot/tmp/build

    bwrap \
      --unshare-net \
      --unshare-pid \
      --clearenv \
      --setenv PATH /bin \
      --setenv TMPDIR /tmp \
      --setenv HOME /home/build \
      --setenv DESTDIR /destdir \
      --bind ./chroot /  \
      --bind ./pkg /destdir  \
      --dev /dev \
      --proc /proc \
      --chdir /home/build \
      -- \
      /tmp/build 2>&1 | tee build.log

    filespec-fromdirs -r pkg pkg \
      | grep -v '^[gu]id:'  \
      | filespec-b3sum -C pkg \
      > "$out"

    chmod -R 700 chroot
    rm -rf chroot
    ;;
  run-deps | build-deps | files)
    touch "$out"
    ;;
  build)
    echo "$1 is a mandatory file."
    exit 1
    ;;
  all)
    redo-ifchange pkg.filespec
    ;;
  *)
    redo-ifchange files
    
    hash=""
    found=false
    for line in $(cat files)
    do
      hash=$(echo "$line" | cut -f -1 -d ' ')
      name=$(echo "$line" | cut -f 2- -d ' ' | sed 's/^[[:space:]]*//')
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

    if ! $scriptdir/../bin/fetch "$hash" "$out"
    then
      echo "unable to fetch $pkgdir/$filename"
      exit 1
    fi
esac
