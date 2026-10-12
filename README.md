# nvim

A [LazyVim](https://www.lazyvim.org) config. Catppuccin Mocha on a transparent
background, colors tracking a GoLand scheme; j/k swapped; comma as a second
leader. Go, Rust, TypeScript, Zig, Gleam and Nix via LazyVim extras
(`lazyvim.json`); Protobuf via buf (`lua/plugins/proto.lua`).

## Layout

```
init.lua                 bootstrap
lua/config/              LazyVim hooks — kept thin, they wire lua/util/ to events/keys
  options.lua            vim options, root detection (cwd), snacks globals
  keymaps.lua            every custom mapping, grouped and described
  autocmds.lua           wires diagnostics, quit-with-explorer, autosave, scrolloff, folds, sessions
lua/util/                feature logic, one module per feature
  editing.lua            indent a selection and keep it; leave insert mode without stepping back
  diagnostics.lua        gopls' shadowed-variable diagnostics don't render (the colour already says it)
  goto.lua               gd (definition, else usages popup) and gh (tagstack pop)
  symbols.lua            gs workspace symbol search minus the noise
  noise.lua              what counts as test/generated code (paths + rust treesitter)
  popup.lua              gk hover / ge diagnostics styling and <Esc> dismissal
  explorer.lua           sidebar open/focus/close helpers (snacks; a neo-tree backend is kept)
  autosave.lua           debounced normal-mode autosave, no formatting
  scroll.lua             'scrolloff' holds past the end of the buffer
  foldranges.lua         the fold expression: the language server's ranges (normalised), treesitter's until then
  folds.lua              folds persist across sessions, anchored to the text they hide
  foldtext.lua           closed folds read `func main() { ... }`, first line highlighted
  searchfolds.lua        a search doesn't unfold what it passes through
  harpoon.lua            a harpoon jump from an empty buffer replaces it instead of adding a tab
  session.lua            a bare `nvim` restores the directory's session instead of the dashboard
lua/plugins/             one lazy.nvim spec per plugin (LazyVim merges them)
lua/benched/             shelved specs (neo-tree) — not imported, see its README
queries/<lang>/context.scm   treesitter-context: pin declarations only, not loops/ifs
tests/                   headless regression suite — tests/run.sh
```

Conventions: `lua/config/*` holds no logic — a mapping or autocmd calls into
`lua/util/`, where every function with a body lives. `lua/plugins/*` is one
lazy.nvim spec per plugin; a spec may build its own `opts`, but behaviour
behind a key still goes through `lua/util/`. Every mapping has a `desc`
(which-key and `<leader>sk` are the cheat sheet). Visual-mode maps use `x`,
not `v`. Formatting is stylua (`stylua.toml`), tests included.

## Custom keys

Navigation: `j`/`k` are swapped everywhere — motions, operators, picker
lists, `<C-j>`/`<C-k>` in pickers and terminals, `<C-w>j`/`<C-w>k`, `zj`/`zk`,
undotree's `J`/`K`. `S-J`/`S-K` half page, `S-H`/`S-L` line start/end. `w`/`e`/`b` hop alphanumeric words
only (w back, e next start, b next end); `W`/`E`/`B` likewise for WORDs.

| key | does |
|---|---|
| `gd` | goto definition; on the definition itself, open its usages (one usage jumps straight there) |
| `gh` | back to where the last jump came from (tagstack) |
| `gs` / `g/` | workspace symbols / project grep (literal, no escaping) |
| `gk` / `ge` | hover docs / line diagnostics, in a cursor popup; `<Esc>` dismisses; `gd` inside the hover follows a link (file links jump there, https opens the browser) |
| `,a` / `,c` | toggle-focus / close the explorer sidebar |
| `,q` `,f` `,r` `,g` `,d` `,j` `,u` | close buffer, format+save, rename, code action, fold, split/join, undotree |
| `-` / `,o` | oil: edit the current file's directory / the project root as a buffer (float) |
| `,ha` `,hl` `,1`…`,9` | harpoon: pin file, open the list, jump to slot |
| `,w` `,e` `<leader>j` `<leader>k` | window left / right / up / down |
| `A-h` / `A-l` | previous / next buffer |
| `C-j` / `C-k` | add multicursor above / below |
| `Tab` / `S-Tab` (visual) | indent / dedent keeping the selection |
| `d` `D` `x`-mode `p` `s` `<BS>` `<Del>` | never touch the clipboard |
| `"` `'` `` ` `` `(` `[` `{` `<` (visual) | wrap the selection |
| `jj` | leave insert mode |

## Behaviour worth knowing

- **Autosave**: a buffer is written the moment you leave insert mode (`jj`)
  and 300ms after a normal-mode edit, never mid-typing, and never formatted —
  `,f` formats.
- **Diagnostics**: only errors get virtual text. Go's `shadow` diagnostic is
  dropped; shadowed variables get a color instead.
- **Formatting**: goimports + `golangci-lint fmt` for Go, the project's
  prettier for JS/TS, `buf format` for proto; mason binaries lose to the
  project's PATH.
- **Protobuf**: `buf lsp serve` gives compile errors, buf lint (per the
  module's `buf.yaml`), navigation, rename and completion. Breaking-change
  checks aren't exposed over LSP — run `buf breaking`.
- **Folds are the language server's** (rust-analyzer, gopls, vtsls… fold
  every bracket region: a struct literal inside a closure, wrapped
  arguments, each branch of an if/else), normalised so a closed fold hides
  its closing bracket the way IntelliJ does — servers stop a line short and
  leave `}` / `});` / `}, log)` visible. Treesitter's folds serve until the
  server answers and where none does; indentation folds files with no
  parser. A closed fold is drawn as its first line (highlighted) plus
  ` ... }`; the dots and the bracket are only drawn. `,d` folds the region
  at the cursor the way JetBrains does, each on its own: wrapped parameters
  read `fn f( ... ) -> R {`, an if branch `if x { ... } else {`, an else
  branch `} else { ... }` — the line two regions share goes to the one
  being folded. Fold the other one while that is still folded and the pair
  collapses to its chain: `if x { ... } else { ... }`. Import blocks are
  folded when a file opens, as JetBrains does (the server's `imports` fold
  kind: gopls' `import (…)`, rust-analyzer's run of `use` items).
- **Searching doesn't unfold**: a match inside a closed fold opens that
  fold only while the cursor is in it (`/`, `n`, `N`, `*`, `#`); step out
  and it closes again, unless you edited inside. Folds a search merely
  passed over never open.
- **Sessions**: a bare `nvim` in a directory you've worked in restores that
  session (persistence.nvim) instead of showing the dashboard; the dashboard
  appears only when there's nothing to restore. Quitting with no file open
  forgets the directory's session, so the next bare `nvim` there starts
  with the dashboard again.
- **Folds persist**: close a fold, come back to the file next week, it's
  still closed — if the same text is still there (it follows the text when
  lines shift; edited text is left unfolded rather than folded wrong).
- **Root** is the directory nvim was launched from, not the LSP root.

## Tests

`tests/run.sh` drives headless nvim against small Go, Rust and protobuf
fixtures and prints PASS/FAIL per behaviour. Suites: `go` (gd/gh, usages
popup, autosave, popups, fold shapes with gopls), `rust` (gs filtering,
italics, fold shapes with rust-analyzer), `session`, `copilot`, `proto`,
`scroll`, `keys` (j/k swaps), `ranges` (the fold-range normaliser against
captured server output, no server needed) and `folds` (persistence across
two runs, plain text and treesitter/LSP). Needs gopls, rust-analyzer and
buf.
