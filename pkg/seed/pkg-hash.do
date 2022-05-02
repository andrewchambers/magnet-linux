redo-ifchange files
(
  echo chash
  cat files
) | sha256sum | cut -c 1-64 > "$3"