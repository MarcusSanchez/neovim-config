#!/usr/bin/env bash
# Headless regression suite for the custom behaviour in this config.
# Needs gopls, rust-analyzer and buf on PATH (mason installs them).
#
#   tests/run.sh          # everything
#   tests/run.sh go       # one suite: go | rust | session | proto | scroll | keys | folds
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
# every suite's nvim state (sessions, shada, swap, saved folds) goes to the
# temp dir, never the real ~/.local/state
export XDG_STATE_HOME="$work/state"

run() { # name, cwd, file to open, lua script, result log
  local name=$1 cwd=$2 file=$3 script=$4 log=$5
  # portable timeout (macOS ships no `timeout`): kill nvim after 180s
  (cd "$cwd" && nvim --headless ${file:+"$file"} -c "luafile $script" >/dev/null 2>&1) &
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
if [[ $want == all || $want == session ]]; then
  # its own state dir: other suites' exits save sessions for the fixture dirs
  export XDG_STATE_HOME="$work/state-session" SESSION_PASS=1
  (cd "$work/go" && nvim --headless -c "luafile $here/session.lua" >/dev/null 2>&1)
  SESSION_PASS=2 run session "$work/go" "" "$here/session.lua" "$work/go/result.log"
  unset SESSION_PASS
  export XDG_STATE_HOME="$work/state"
fi
[[ $want == all || $want == proto ]] && run proto "$work/proto" acme/v1/user.proto "$here/proto.lua" "$work/proto/result.log"
if [[ $want == all || $want == scroll || $want == keys || $want == folds ]]; then
  seq 1 100 | sed 's/^/line /' > "$work/long.txt"
  [[ $want == all || $want == scroll ]] && run scroll "$work" long.txt "$here/scroll.lua" "$work/result.log"
  [[ $want == all || $want == keys ]] && run keys "$work" long.txt "$here/keys.lua" "$work/result.log"
  if [[ $want == all || $want == folds ]]; then
    # two sessions: the first folds and quits, the second must find the folds
    { for b in one two three; do echo "block $b"; for i in 1 2 3 4 5 6 7 8 9; do echo "    $b line $i"; done; done; } > "$work/folds.txt"
    export FOLD_PASS=1
    (cd "$work" && nvim --headless folds.txt -c "luafile $here/folds.lua" >/dev/null 2>&1)
    # shift everything down and change block three's content before pass 2
    { echo "new header"; echo "another"; echo "third"; sed 's/three line 5/three line 5 EDITED/' "$work/folds.txt"; } > "$work/folds.tmp" && mv "$work/folds.tmp" "$work/folds.txt"
    FOLD_PASS=2 run folds "$work" folds.txt "$here/folds.lua" "$work/result.log"
    # same again for treesitter (async) folds, on the rust fixture
    export FOLD_PASS=1
    (cd "$work/rust" && nvim --headless src/lib.rs -c "luafile $here/folds_ts.lua" >/dev/null 2>&1)
    FOLD_PASS=2 run folds-treesitter "$work/rust" src/lib.rs "$here/folds_ts.lua" "$work/rust/result.log"
    unset FOLD_PASS
  fi
fi
exit $status
