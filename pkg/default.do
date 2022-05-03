set -eux
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

		if test -s run-deps
		then
			redo-ifchange $(
				for dep in $(cat run-deps); do
					if ! test -d "$dep"; then
						echo "runtime dependency $dep of $pkgdir does not exist" >&2
						exit 1
					fi
					echo "$dep/run-closure"
				done
			)
			realpath --relative-to "." $(
				for dep in $(cat run-deps); do
					echo "$dep"
					for closed_over in $(cat "$dep/run-closure"); do
						echo "$dep/$closed_over"
					done
				done
			) | sort -u > "$out"
		fi

		touch "$out"
		;;
	build-closure)
		redo-ifchange build-deps
		
		if test -s build-deps
		then
			redo-ifchange $(
				for dep in $(cat build-deps); do
					if ! test -d "$dep"; then
						echo "build dependency $dep of $pkgdir does not exist" >&2
						exit 1
					fi
					echo "$dep/run-closure"
				done
			)
			realpath --relative-to "." $(
				for dep in $(cat build-deps); do
					echo "$dep"
					for closed_over in $(cat "$dep/run-closure"); do
						echo "$dep/$closed_over"
					done
				done
			) | sort -u > "$out"
		fi

		touch "$out"
		;;
	pkg-hash)
		redo-ifchange \
			build \
			build-closure
		if test -s build-closure
		then
			redo-ifchange $(printf "%s/pkg-hash\n" $(cat build-closure))
		fi
		(
			echo shash
			echo files
			cat files | sort
			echo build
			cat build
			echo build-closure
			if test -s build-closure
			then
				cat $(printf "%s/pkg-hash\n" $(cat build-closure))
			fi
		) | sha256sum | cut -c 1-64 > "$out"
		;;
	pkg.filespec)
		umask 022

		redo-ifchange \
			build \
			build-closure \
			run-closure \
			files

		files=$(
			awk '{
				if (NF != 2) { print("too many columns in", $0) > "/dev/stderr"; exit 1; };
				print $2;
			}' files
		)
		if test -n "$files"
		then
			redo-ifchange $files
		fi

		sha256sum --quiet -c files

		redo-ifchange $(
			printf "%s/pkg.filespec\n" $(cat build-closure run-closure)
		)

		echo "preparing build chroot..."
		
		if test -e chroot
		then
			chmod -R 700 chroot
			rm -rf chroot
		fi

		mkdir \
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
		filespec-sort -u $(
			printf "%s/pkg.filespec\n" $(cat build-closure)
		) > /dev/null

		for pkg in $(cat build-closure)
		do
			filespec-b3sum -C "$pkg" -c "$pkg/pkg.filespec" \
				| filespec-tar -C "$pkg" \
				| tar -C ./chroot -xf -
		done

		for file in $(awk '{ print $2; }' files)
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
			--dev /dev \
			--proc /proc \
			--chdir /home/build \
			-- \
			/tmp/build 2>&1 | tee build.log

		test -d .pkgdata && rm -rf .pkgdata

		filespec-fromdirs -r chroot/destdir chroot/destdir \
			| filespec-tar -C chroot/destdir \
			| filespec-fromtar -H -d .pkgdata \
			> "$out"

		chmod -R 700 chroot
		rm -rf chroot
		;;
	build | run-deps | build-deps | files)
		echo "no default rule to build $1."
		exit 1
		;;
	all)
		redo-ifchange pkg.filespec
		;;
	*)
		redo-ifchange files

		hash=$(
			awk -v f="$filename" '{if ($2 == f) { print $1; exit 0; };}' files
		)

		if ! test -n "$hash"
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
