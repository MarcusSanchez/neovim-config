#!/usr/bin/env bash
set -euo pipefail

# a comment
# spanning lines
usage() {
  echo "usage: $0 <dir>"
  exit 1
}

main() {
  local dir=$1
  if [[ -d $dir ]]; then
    echo "dir"
  elif [[ -f $dir ]]; then
    echo "file"
  else
    usage
  fi
  for f in "$dir"/*; do
    echo "$f"
  done
  while read -r line; do
    echo "$line"
  done < /dev/null
  case $dir in
    /tmp)
      echo tmp
      ;;
    *)
      echo other
      ;;
  esac
  cat <<EOT
heredoc
text
EOT
  {
    echo grouped
  }
}

main "$@"
