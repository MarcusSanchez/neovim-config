#!/usr/bin/env bash
# Headless regression suite for the custom behaviour in this config.
# Needs gopls, rust-analyzer, vtsls, zls, clangd, gleam, buf, lua-language-server,
# bash-language-server, the json/yaml servers, taplo, marksman, nil and ruff on
# PATH (mason installs all but gleam, which comes with its compiler).
#
#   tests/run.sh          # everything
#   tests/run.sh go       # one suite (the names are in `suites` below)
#
# Each suite drives a real nvim with this config against a fixture project
# and prints PASS/FAIL lines. Fixtures are copied to a temp dir first: the
# repo's own path contains "tests/", which lua/util/noise.lua treats as test
# code, and cargo/gopls scratch output stays out of the tree.
set -u
here=$(cd "$(dirname "$0")" && pwd)
suites="go caret rust tsx zig gleam c cpp lua sh json yaml toml markdown nix python protofold session copilot proto scroll keys comment ranges folds"
want=${1:-all}
if [[ $want != all ]] && ! grep -qw -- "$want" <<< "$suites"; then
  echo "usage: tests/run.sh [all | $(echo $suites | tr ' ' '|')]" >&2; exit 2
fi
work=$(mktemp -d "${TMPDIR:-/tmp}/nvim-tests.XXXXXX")
trap 'rm -rf "$work"' EXIT
cp -R "$here/fixtures/." "$work/"
status=0
# every suite's nvim state (sessions, shada, swap, saved folds) goes to the
# temp dir, never the real ~/.local/state
export XDG_STATE_HOME="$work/state"

timed() { # cwd, file to open (may be empty), lua script: a headless nvim,
  # killed after 180s (portable: macOS ships no `timeout`)
  local cwd=$1 file=$2 script=$3
  (cd "$cwd" && exec nvim --headless ${file:+"$file"} -c "luafile $script" >/dev/null 2>&1) &
  local pid=$!
  for _ in $(seq 1 180); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
  kill -9 "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
}

run() { # name, cwd, file to open, lua script, result log [, keep]
  local name=$1 cwd=$2 file=$3 script=$4 log=$5
  # never report a stale log as this run's — unless a first pass just
  # wrote it and this pass appends to it
  [[ ${6:-} == keep ]] || rm -f "$log"
  timed "$cwd" "$file" "$script"
  echo "== $name"
  if [[ -f $log ]]; then
    cat "$log"
    grep -qE '^(FAIL|ERROR|TIMEOUT)' "$log" && status=1
    grep -qx 'DONE' "$log" || status=1
  else
    echo "no result written"; status=1
  fi
}

[[ $want == all || $want == go ]] && run go "$work/go" main.go "$here/go.lua" "$work/go/result.log"
[[ $want == all || $want == caret ]] && run caret "$work/go" main.go "$here/caret.lua" "$work/go/result.log"
[[ $want == all || $want == rust ]] && run rust "$work/rust" src/lib.rs "$here/rust.lua" "$work/rust/src/result.log"
[[ $want == all || $want == tsx ]] && run tsx "$work/ts" page.tsx "$here/tsx.lua" "$work/ts/result.log"
[[ $want == all || $want == zig ]] && run zig "$work/zig" src/main.zig "$here/zig.lua" "$work/zig/src/result.log"
[[ $want == all || $want == gleam ]] && run gleam "$work/gleam" src/probe.gleam "$here/gleam.lua" "$work/gleam/src/result.log"
[[ $want == all || $want == c ]] && run c "$work/c" main.c "$here/c.lua" "$work/c/result.log"
[[ $want == all || $want == cpp ]] && run cpp "$work/cpp" main.cpp "$here/cpp.lua" "$work/cpp/result.log"
[[ $want == all || $want == lua ]] && run lua "$work/lua" main.lua "$here/lua.lua" "$work/lua/result.log"
[[ $want == all || $want == sh ]] && run sh "$work/sh" script.sh "$here/sh.lua" "$work/sh/result.log"
[[ $want == all || $want == json ]] && run json "$work/json" data.json "$here/json.lua" "$work/json/result.log"
[[ $want == all || $want == yaml ]] && run yaml "$work/yaml" config.yaml "$here/yaml.lua" "$work/yaml/result.log"
[[ $want == all || $want == toml ]] && run toml "$work/toml" config.toml "$here/toml.lua" "$work/toml/result.log"
[[ $want == all || $want == markdown ]] && run markdown "$work/md" README.md "$here/markdown.lua" "$work/md/result.log"
[[ $want == all || $want == nix ]] && run nix "$work/nix" pkgs.nix "$here/nix.lua" "$work/nix/result.log"
[[ $want == all || $want == python ]] && run python "$work/py" main.py "$here/python.lua" "$work/py/result.log"
[[ $want == all || $want == protofold ]] && run protofold "$work/proto" acme/v1/shapes.proto "$here/protofold.lua" "$work/proto/acme/v1/result.log"
if [[ $want == all || $want == session ]]; then
  # its own state dir: other suites' exits save sessions for the fixture dirs
  export XDG_STATE_HOME="$work/state-session" SESSION_PASS=1
  rm -f "$work/go/result.log" "$work/go/session.path"
  timed "$work/go" "" "$here/session.lua"
  SESSION_PASS=2 run session "$work/go" "" "$here/session.lua" "$work/go/result.log" keep
  # pass 2 quits with no file open: that forgets the directory's session
  # (pass 2 wrote the session file's path, as util/session computes it)
  sess=$(cat "$work/go/session.path" 2>/dev/null)
  if [[ -z $sess ]]; then echo "FAIL pass 2: no session file path recorded"; status=1
  elif [[ -f $sess ]]; then echo "FAIL pass 2: quitting with no file open forgets the session: file still there"; status=1
  else echo "PASS pass 2: quitting with no file open forgets the session"; fi
  unset SESSION_PASS
  export XDG_STATE_HOME="$work/state"
fi
if [[ $want == all || $want == copilot ]]; then
  # a fake orphaned server (argv carries the server path; its parent exits so
  # launchd adopts it) for the startup reaper; then the real nvim is SIGKILLed
  # and the real server must die with it
  ( bash -c 'exec -a "FAKE-ORPHAN '"$here"'/../x/copilot.lua/copilot/js/language-server.js" sleep 300' >/dev/null 2>&1 & )
  sleep 1
  rm -f "$work/go/ready" "$work/go/server.pid" "$work/go/result.log"
  (cd "$work/go" && exec nvim --headless main.go -c "luafile $here/copilot.lua" >/dev/null 2>&1) &
  nvpid=$!
  for _ in $(seq 1 90); do [[ -f $work/go/ready ]] && break; sleep 1; done
  echo "== copilot"
  if [[ -f $work/go/result.log ]]; then cat "$work/go/result.log"; else echo "no result written"; status=1; fi
  kill -9 "$nvpid" 2>/dev/null; wait "$nvpid" 2>/dev/null
  srv=$(cat "$work/go/server.pid" 2>/dev/null)
  if [[ -n $srv ]]; then
    gone=""
    for i in $(seq 1 15); do kill -0 "$srv" 2>/dev/null || { gone=$i; break; }; sleep 1; done
    if [[ -n $gone ]]; then echo "PASS server died after nvim was SIGKILLed (~${gone}s)"; else echo "FAIL server SURVIVED nvim's SIGKILL"; status=1; kill -9 "$srv"; fi
  else
    echo "FAIL no server pid recorded"; status=1
  fi
  pkill -f 'FAKE-ORPHAN' 2>/dev/null
  grep -qE '^(FAIL|ERROR|TIMEOUT)' "$work/go/result.log" 2>/dev/null && status=1
fi
[[ $want == all || $want == proto ]] && run proto "$work/proto" acme/v1/user.proto "$here/proto.lua" "$work/proto/result.log"
if [[ $want == all || $want == scroll || $want == keys || $want == comment || $want == ranges || $want == folds ]]; then
  [[ $want == all || $want == scroll ]] && run scroll "$work" long.txt "$here/scroll.lua" "$work/result.log"
  [[ $want == all || $want == keys ]] && run keys "$work" long.txt "$here/keys.lua" "$work/result.log"
  [[ $want == all || $want == comment ]] && run comment "$work" long.txt "$here/comment.lua" "$work/result.log"
  [[ $want == all || $want == ranges ]] && run ranges "$work" long.txt "$here/ranges.lua" "$work/result.log"
  if [[ $want == all || $want == folds ]]; then
    # two sessions: the first folds and quits, the second must find the folds
    { for b in one two three; do echo "block $b"; for i in 1 2 3 4 5 6 7 8 9; do echo "    $b line $i"; done; done; } > "$work/folds.txt"
    export FOLD_PASS=1
    rm -f "$work/result.log"
    timed "$work" folds.txt "$here/folds.lua"
    # shift everything down and change block three's content before pass 2
    { echo "new header"; echo "another"; echo "third"; sed 's/three line 5/three line 5 EDITED/' "$work/folds.txt"; } > "$work/folds.tmp" && mv "$work/folds.tmp" "$work/folds.txt"
    FOLD_PASS=2 run folds "$work" folds.txt "$here/folds.lua" "$work/result.log" keep
    # same again for treesitter (async) folds, on the rust fixture
    export FOLD_PASS=1
    rm -f "$work/rust/result.log"
    timed "$work/rust" src/lib.rs "$here/folds_ts.lua"
    FOLD_PASS=2 run folds-treesitter "$work/rust" src/lib.rs "$here/folds_ts.lua" "$work/rust/result.log" keep
    unset FOLD_PASS
  fi
fi
exit $status
