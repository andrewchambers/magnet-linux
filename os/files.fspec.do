exec > "$3"

redo-always

for f in $(find etc)
do
  echo "/$f"
  if test -f "$f"
  then
  	echo "type=file"
  	echo "source=./$f"
  elif test -d "$f"
  then
    echo "type=dir"
  elif test -L "$f"
  then
    echo "type=symlink"
    echo "target=$(readlink $f)"
  else
    echo "unknown type for $f" >&2
    exit 1
  fi

  echo ""
done