#!/usr/bin/env bash
# Headless regression suite for the custom behaviour in this config.
# Needs gopls and rust-analyzer on PATH (mason installs both).
#
#   tests/run.sh          # everything
#   tests/run.sh go       # one suite: go | rust | scroll
#
# Each suite drives a real nvim with this config against a fixture project
# and prints PASS/FAIL lines. Fixtures are copied to a temp dir first: the
# repo's own path contains "tests/", which lua/util/noise.lua treats as test
# code, and cargo/gopls scratch output stays out of the tree.
set -u
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d -t nvim-tests)
trap 'rm -rf "$work"' EXIT
cp -R "$here/fixtures/." "$work/"
status=0

run() { # name, cwd, file to open, lua script, result log
  local name=$1 cwd=$2 file=$3 script=$4 log=$5
  # portable timeout (macOS ships no `timeout`): kill nvim after 180s
  (cd "$cwd" && nvim --headless "$file" -c "luafile $script" >/dev/null 2>&1) &
  local pid=$!
  for _ in $(seq 1 180); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
  kill -9 "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  echo "== $name"
  if [[ -f $log ]]; then
    cat "$log"
    grep -q '^FAIL\|ERROR\|TIMEOUT' "$log" && status=1
    grep -q 'OK\|DONE' "$log" || status=1
  else
    echo "no result written"; status=1
  fi
}

want=${1:-all}
[[ $want == all || $want == go ]] && run go "$work/go" main.go "$here/go.lua" "$work/go/result.log"
[[ $want == all || $want == rust ]] && run rust "$work/rust" src/lib.rs "$here/rust.lua" "$work/rust/result.log"
if [[ $want == all || $want == scroll ]]; then
  seq 1 100 | sed 's/^/line /' > "$work/long.txt"
  run scroll "$work" long.txt "$here/scroll.lua" "$work/result.log"
fi
exit $status
