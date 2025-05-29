-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set
local del = vim.keymap.del
local opts = { noremap = true, silent = true }

--------------------------------------------------------------------------------
-- Navigation
--------------------------------------------------------------------------------

-- Jump to start/end of line with Shift+H/L in normal and visual mode
map({ "n", "v" }, "<S-h>", "^", opts)
map({ "n", "v" }, "<S-l>", "$", opts)

-- Jump half page up/down with Shift+J/K
map({ "n", "v" }, "<S-J>", "<C-U>", opts)
map({ "n", "v" }, "<S-K>", "<C-D>", opts)

-- Swap j and k in normal, visual, operator-pending, and select mode
map({ "n", "x", "o", "v" }, "j", "k", opts)
map({ "n", "x", "o", "v" }, "k", "j", opts)

-- Swap dj and dk
map("n", "dj", "dk", opts)
map("n", "dk", "dj", opts)

--------------------------------------------------------------------------------
-- Indentation & Tabs
--------------------------------------------------------------------------------

-- <Tab> in visual mode to indent and stay in visual mode
map("v", "<Tab>", ">gv4lo4lo", opts)
map("v", "<S-Tab>", "<:set whichwrap-=h,l<CR>gv4ho4hv:set whichwrap+=h,l<CR>gvo", opts)
map("n", "<S-Tab>", "<<", opts)

-- <Tab> in normal mode to insert a tab
map("n", "<Tab>", "i<tab>", opts)

--------------------------------------------------------------------------------
-- Insert Mode Enhancements
--------------------------------------------------------------------------------

-- 'jj' to exit insert mode
map("i", "jj", "<Esc>`^", opts)

-- Prevent cursor movement when exiting insert mode
map("i", "<Esc>", "<Esc>`^", opts)

--------------------------------------------------------------------------------
-- Line Manipulation
--------------------------------------------------------------------------------

-- Shift+N collapses content (joins lines)
map("n", "<S-N>", "J", opts)

-- Normal mode - move lines up and down (reversed)
map("n", "<S-A-j>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = "Move Up (reversed)" })
map("n", "<S-A-k>", "<cmd>execute 'move .+' . v:count1<cr>==", { desc = "Move Down (reversed)" })

-- Insert mode - move lines up and down (reversed)
map("i", "<S-A-j>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move Up (reversed)" })
map("i", "<S-A-k>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move Down (reversed)" })

-- Visual mode - move lines up and down (reversed)
map("v", "<S-A-j>", ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = "Move Up (reversed)" })
map("v", "<S-A-k>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Move Down (reversed)" })

--------------------------------------------------------------------------------
-- Buffer & Window Management
--------------------------------------------------------------------------------

-- let ,q close current buffer
map("n", ",q", "<leader>bd", { remap = true, desc = "Close current buffer" })

-- let ,f format the current buffer
map("n", ",f", ":w<CR>", { desc = "(Format + Save) current buffer" })

-- use ,a to open snacks explorer
map("n", ",a", "<leader>e", { remap = true, desc = "Open snacks explorer (root dir)" })

-- use ,w and ,e to cycle buffers
map("n", ",w", "<C-w>h", { desc = "Go to Left Window" })
map("n", ",e", "<C-w>l", { desc = "Go to Right Window" })
map("n", "<leader>j", "<C-w>k", { desc = "Go to Top Window" })
map("n", "<leader>k", "<C-w>j", { desc = "Go to Bottom Window" })

-- use Alt + (h/l) to go forward and back buffers
map("n", "<A-h>", "<cmd>bprevious<cr>", { desc = "Previous Buffer" })
map("n", "<A-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })

--------------------------------------------------------------------------------
-- Clipboard, Delete, and Yank Behavior
--------------------------------------------------------------------------------

-- Backspace and Delete without yanking to clipboard
map({ "n", "v" }, "<BS>", [["_dh]], opts)
map({ "n", "v" }, "<Del>", [["_<Del>]], opts)

-- Prevent 'd', 'D' from yanking
map({ "n", "v" }, "d", [["_d]], opts)
map("n", "D", [["_D]], opts)

-- Prevent 'p' and 'P' in visual mode from yanking
map("v", "p", [["_dP]], opts)
map("v", "P", [["_dP]], opts)

-- return s to itself in search
map("v", "s", [["_di]], opts)

--------------------------------------------------------------------------------
-- Word Motions Customization
--------------------------------------------------------------------------------

-- Skip over non-alphanumeric characters with w/e, make b go to end of word
map("n", "w", ":set noincsearch<CR>?\\w\\+<CR>:set incsearch<CR>:noh<CR>", opts)
map("n", "e", ":set noincsearch<CR>/\\w\\+<CR>:set incsearch<CR>:noh<CR>", opts)
map("v", "w", "b", opts)
map("v", "e", "w", opts)
map("n", "b", "e", opts)
map("n", "W", "B", opts)
map("n", "E", "W", opts)
map("n", "B", "E", opts)

--------------------------------------------------------------------------------
-- Miscellaneous Utility Keymaps
--------------------------------------------------------------------------------

-- Shift+U to redo
map("n", "<S-U>", "<C-R>", opts)

-- ,d to fold under cursor
map("n", ",d", "za", { desc = "Toggle Fold Under Cursor" })

-- ,r to rename symbol under cursor
map("n", ",r", "<leader>cr", { remap = true, desc = "Rename Symbol Under Cursor" })

-- <leader>hc to show ts captures under cursor
map("n", "<leader>hc", ":TSHighlightCapturesUnderCursor<CR>", { desc = "Show Treesitter Captures Under Cursor" })

-- del("n", "<C-/>")
-- map("n", "<C-/>", "gc<Esc><Down>", { desc = "Comment Line" })
-- map("v", "<C-/>", "gc<Esc><Down>", { desc = "Comment Selection" })

--------------------------------------------------------------------------------
-- LSP & Diagnostics
--------------------------------------------------------------------------------

-- Quick documentation with 'gk'
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    map("n", "gk", vim.lsp.buf.hover, { buffer = args.buf, desc = "LSP Hover" })
  end,
})

-- make ge open the diagnostic window in a float
map("n", "ge", function()
  vim.diagnostic.open_float()
end)

-- make ,g open code actions
map("n", ",g", "<leader>ca", { remap = true, desc = "Code Actions" })

--------------------------------------------------------------------------------
-- Multicursor
--------------------------------------------------------------------------------

-- Remove default multicursor mappings
del("n", "<A-k>")
del("n", "<A-j>")

local mc = require("multicursor-nvim")
map({ "n", "x" }, "<C-j>", function()
  mc.lineAddCursor(-1, { skipEmpty = false })
end)
map({ "n", "x" }, "<C-k>", function()
  mc.lineAddCursor(1, { skipEmpty = false })
end)

--------------------------------------------------------------------------------
-- Text Wrapping (tenaille.nvim)
--------------------------------------------------------------------------------

require("tenaille").setup({ default_mapping = false })
local wrap = require("tenaille").wrap

map("v", '"', function()
  wrap({ '"', '"' })
end)
map("v", "'", function()
  wrap({ "'", "'" })
end)
map("v", "`", function()
  wrap({ "`", "`" })
end)
map("v", "(", function()
  wrap({ "(", ")" })
end)
map("v", "[", function()
  wrap({ "[", "]" })
end)
map("v", "{", function()
  wrap({ "{", "}" })
end)
map("v", "<", function()
  wrap({ "<", ">" })
end)
