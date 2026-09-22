# nvim

A [LazyVim](https://www.lazyvim.org) config. Catppuccin Mocha on a transparent
background, colors tracking a GoLand scheme; j/k swapped; comma as a second
leader. Go, Rust, TypeScript, Zig, Gleam and Nix via LazyVim extras
(`lazyvim.json`).

## Layout

```
init.lua                 bootstrap
lua/config/              LazyVim hooks — kept thin, they wire lua/util/ to events/keys
  options.lua            vim options, root detection (cwd), snacks globals
  keymaps.lua            every custom mapping, grouped and described
  autocmds.lua           diagnostics tweaks, quit-with-explorer, autosave, scrolloff
lua/util/                feature logic, one module per feature
  goto.lua               gd (definition, else usages popup) and gh (tagstack pop)
  symbols.lua            gs workspace symbol search minus the noise
  noise.lua              what counts as test/generated code (paths + rust treesitter)
  popup.lua              gk hover / ge diagnostics styling and <Esc> dismissal
  explorer.lua           snacks explorer open/focus/close helpers
  autosave.lua           debounced normal-mode autosave, no formatting
  scroll.lua             'scrolloff' holds past the end of the buffer
lua/plugins/             one lazy.nvim spec per plugin (LazyVim merges them)
lua/benched/             shelved specs (oil, harpoon) — not imported, see its README
queries/<lang>/context.scm   treesitter-context: pin declarations only, not loops/ifs
tests/                   headless regression suite — tests/run.sh
```

Conventions: `lua/config/*` and `lua/plugins/*` hold no logic beyond a few
lines — anything with a function body lives in `lua/util/`. Every mapping has
a `desc` (which-key and `<leader>sk` are the cheat sheet). Visual-mode maps
use `x`, not `v`. Formatting is stylua (`stylua.toml`).

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
| `gk` / `ge` | hover docs / line diagnostics, in a cursor popup; `<Esc>` dismisses |
| `,a` / `,c` | toggle-focus / close the explorer sidebar |
| `,q` `,f` `,r` `,g` `,d` `,j` `,u` | close buffer, format+save, rename, code action, fold, split/join, undotree |
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
  prettier for JS/TS; mason binaries lose to the project's PATH.
- **Root** is the directory nvim was launched from, not the LSP root.

## Tests

`tests/run.sh` drives headless nvim against small Go and Rust fixtures and
prints PASS/FAIL per behaviour (gd/gh, usages popup, gs filtering, autosave,
popups, scrolloff). Needs gopls and rust-analyzer.
