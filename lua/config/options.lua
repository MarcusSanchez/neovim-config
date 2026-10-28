-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- LazyVim adds "I" to shortmess, which hides nvim's stock intro screen.
-- Keep it removed so the vanilla greeting shows whenever the snacks dashboard
-- (plugins/dashboard.lua) isn't the one drawing the start screen — except a
-- session-restoring start, which puts it back (see dashboard.lua).
vim.opt.shortmess:remove("I")

-- No snacks animations (scroll, windows, cursor)
vim.g.snacks_animate = false
-- Copilot as ghost text, not as completion entries
vim.g.ai_cmp = false
-- h/l cross line ends (the fold caret follows suit: lua/util/foldcursor.lua)
vim.opt.whichwrap:append("h,l")

-- the terminal tab title
vim.opt.title = true
vim.opt.titlestring = "nvim"

-- Root detection: always use the cwd nvim was launched from, not the
-- LSP workspace root. Keeps <space><space>/g/ searching the whole repo
-- (frontend/, mobile/, ...) even when editing backend/main.go.
vim.g.root_spec = { "cwd" }

-- Folds: one fold expression everywhere (lua/util/foldranges.lua) — the
-- language server's folding ranges, treesitter's until they arrive,
-- indentation without a parser. LazyVim's own switches (treesitter folds
-- in plugins/treesitter.lua, LSP folds in plugins/lsp.lua) are off so
-- nothing swaps the expression out from under it.
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.require('util.foldranges').foldexpr()"
-- Sessions don't record fold options or folds: the options are global
-- (above), and a "setlocal foldmethod=…" replayed from a session would
-- shadow them in that window for good (it gets re-saved on every exit).
-- Folds themselves persist content-anchored via lua/util/folds.lua.
vim.opt.sessionoptions:remove("folds")
-- closed folds read `func main() { ... }` (lua/util/foldtext.lua)
vim.opt.foldtext = "v:lua.require('util.foldtext').text()"

-- No swap files: the file on disk is the truth, always. A swap file's two
-- jobs — recovering unsaved text after a crash, warning that another
-- editor has the file open — are covered by persistent undo and saving
-- often, and the warning meant a notification per buffer at every
-- session restore while another Neovim had the project open. (A swap
-- file met anyway is taken as "edit": config/autocmds.lua.)
vim.opt.swapfile = false
