-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- LazyVim adds "I" to shortmess, which hides nvim's stock intro screen.
-- Keep it removed so the vanilla greeting shows whenever the snacks dashboard
-- (plugins/dashboard.lua) isn't the one drawing the start screen.
vim.opt.shortmess:remove("I")

-- Disable all snacks animations globally
vim.g.snacks_animate = false
vim.g.ai_cmp = false
vim.opt.whichwrap:append("h,l")

-- Root detection: always use the cwd nvim was launched from, not the
-- LSP workspace root. Keeps <space><space>/g/ searching the whole repo
-- (frontend/, mobile/, ...) even when editing backend/main.go.
vim.g.root_spec = { "cwd" }
