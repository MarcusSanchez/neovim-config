-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- LazyVim adds "I" to shortmess, which hides nvim's stock intro screen.
-- Remove it so a bare `nvim` shows the plain vanilla greeting again
-- (the dashboard is disabled in plugins/snacks.lua).
vim.opt.shortmess:remove("I")

-- Disable all snacks animations globally
vim.g.snacks_animate = false
vim.g.ai_cmp = false
vim.opt.whichwrap:append("h,l")
