-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Jump to start/end of line with Shift+H/L in normal and visual mode
map({ "n", "v" }, "<S-h>", "^", opts)
map({ "n", "v" }, "<S-l>", "$", opts)

-- Jump half page up/down with Shift+J/K
map({ "n", "v" }, "<S-J>", "<C-U>", opts)
map({ "n", "v" }, "<S-K>", "<C-D>", opts)

-- Swap j and k in normal and visual mode
map({ "n", "x", "o", "v" }, "j", "k", opts)
map({ "n", "x", "o", "v" }, "k", "j", opts)

-- <Tab> in visual mode to indent and stay in visual mode
map("v", "<Tab>", ">gv4lo4lo", opts)
map("v", "<S-Tab>", "<:set whichwrap-=h,l<CR>gv4ho4hv:set whichwrap+=h,l<CR>gvo", opts)
map("n", "<S-Tab>", "<<", opts)

-- <Tab> in normal mode to insert a tab
map("n", "<Tab>", "i<tab>", opts)

-- 'jj' to exit insert mode
map("i", "jj", "<Esc>`^", opts)

-- Prevent cursor movement when exiting insert mode
map("i", "<Esc>", "<Esc>`^", opts)

-- Shift+N collapses content (joins lines)
map("n", "<S-N>", "J", opts)

-- Backspace and Delete without yanking to clipboard
map({ "n", "v" }, "<BS>", [["_dh]], opts)
map({ "n", "v" }, "<Del>", [["_<Del>]], opts)

-- Custom mapping for wrapping text in delimiter
require("tenaille").setup({ default_mapping = false })
local wrap = require("tenaille").wrap
vim.keymap.set("v", '"', function()
  wrap({ '"', '"' })
end)
vim.keymap.set("v", "'", function()
  wrap({ "'", "'" })
end)
vim.keymap.set("v", "`", function()
  wrap({ "`", "`" })
end)
vim.keymap.set("v", "(", function()
  wrap({ "(", ")" })
end)
vim.keymap.set("v", "[", function()
  wrap({ "[", "]" })
end)
vim.keymap.set("v", "{", function()
  wrap({ "{", "}" })
end)
vim.keymap.set("v", "<", function()
  wrap({ "<", ">" })
end)

-- Skip over non-alphanumeric characters with w/e, make b go to end of word
map("n", "w", ":set noincsearch<CR>?\\w\\+<CR>:set incsearch<CR>:noh<CR>", { noremap = true, silent = true })
map("n", "e", ":set noincsearch<CR>/\\w\\+<CR>:set incsearch<CR>:noh<CR>", { noremap = true, silent = true })
map("v", "w", "b", opts)
map("v", "e", "w", opts)
map("n", "b", "e", opts)
map("n", "W", "B", opts)
map("n", "E", "W", opts)
map("n", "B", "E", opts)

-- Quick documentation with 'gk'
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    vim.keymap.set("n", "gk", vim.lsp.buf.hover, { buffer = args.buf, desc = "LSP Hover" })
  end,
})

-- Prevent 'd', 'D' from yanking
map({ "n", "v" }, "d", [["_d]], opts)
map("n", "D", [["_D]], opts)

-- Prevent 'p' and 'P' in visual mode from yanking
map("v", "p", [["_dP]], opts)
map("v", "P", [["_dP]], opts)

-- Swap dj and dk
map("n", "dj", "dk", opts)
map("n", "dk", "dj", opts)

-- Shift+U to redo
map("n", "<S-U>", "<C-R>", opts)

-- return s to itself in search
map("v", "s", [["_di]], opts)

-- let ,q close current buffer
map("n", ",q", "<leader>bd", { remap = true, desc = "Delete current buffer" })

-- let ,f write the file
map("n", ",f", ":w<CR>", opts)

-- use ,a to open snacks explorer
map("n", ",a", "<leader>e", { remap = true, desc = "Open snacks explorer (root dir)" })

-- use ,w and ,e to cycle buffers
map("n", ",w", "<C-w>h", { desc = "Go to Left Window" })
map("n", ",e", "<C-w>l", { desc = "Go to Right Window" })

-- use Alt + (h/l) to go foward and back buffers
map("n", "<A-h>", "<cmd>bprevious<cr>", { desc = "Previous Buffer" })
map("n", "<A-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })
