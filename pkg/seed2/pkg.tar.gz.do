exec >&2
redo busybox x86_64-linux-musl-native.tgz
sha256sum --quiet -c files
# XXX We should just have a download that does not need post processing...
rm -rf ./fs
mkdir -p fs/bin
cp busybox fs/bin
chmod +x fs/bin/busybox
tar -C fs -xf ./x86_64-linux-musl-native.tgz
for cmd in $(ls fs/x86_64-linux-musl-native/bin)
do
  ln -s "../x86_64-linux-musl-native/bin/$cmd" "./fs/bin/$cmd"
done
for app in $(./fs/bin/busybox --list)
do
  test -e "./fs/bin/$app" || ln -s busybox "./fs/bin/$app"
done
tar -C fs -cvf - . | gzip > "$3"
rm -rf fs

