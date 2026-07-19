-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
-- NOTE: visual-mode maps use "x" (visual only), not "v" (visual + select),
-- so that typing over a snippet placeholder in select mode still inserts text.

local map = vim.keymap.set
local del = vim.keymap.del
local opts = { noremap = true, silent = true }

--------------------------------------------------------------------------------
-- Navigation
--------------------------------------------------------------------------------

-- Jump to start/end of line with Shift+H/L
map({ "n", "x" }, "<S-h>", "_", opts)
map({ "n", "x" }, "<S-l>", "$", opts)

-- Jump half page up/down with Shift+J/K
map({ "n", "x" }, "<S-J>", "<C-U>", opts)
map({ "n", "x" }, "<S-K>", "<C-D>", opts)

-- Swap j and k in normal, visual, and operator-pending mode
-- (operator-pending covers dj/dk, cj/ck, etc. — no separate swaps needed)
map({ "n", "x", "o" }, "j", "k", opts)
map({ "n", "x", "o" }, "k", "j", opts)

--------------------------------------------------------------------------------
-- Indentation & Tabs
--------------------------------------------------------------------------------

-- Indent/dedent the selection while keeping it anchored to the same text.
-- Measures how much each endpoint's line actually shifted, so it works with
-- any shiftwidth and with partially-indented lines.
local function shift_selection(op)
  local cl, cc = vim.fn.line("."), vim.fn.col(".")
  local al, ac = vim.fn.line("v"), vim.fn.col("v")
  local cursor_first = cl < al or (cl == al and cc < ac)
  local clen, alen = #vim.fn.getline(cl), #vim.fn.getline(al)
  vim.cmd("normal! " .. op)
  local cpos = { cl, math.max(cc + #vim.fn.getline(cl) - clen, 1) }
  local apos = { al, math.max(ac + #vim.fn.getline(al) - alen, 1) }
  local first, last = apos, cpos
  if cursor_first then
    first, last = cpos, apos
  end
  vim.fn.setpos("'<", { 0, first[1], first[2], 0 })
  vim.fn.setpos("'>", { 0, last[1], last[2], 0 })
  vim.cmd("normal! gv")
  -- gv leaves the cursor on '>'; put it back on the end the user was on
  if cursor_first then
    vim.cmd("normal! o")
  end
end

map("x", "<Tab>", function()
  shift_selection(">")
end, opts)
map("x", "<S-Tab>", function()
  shift_selection("<")
end, opts)
map("n", "<S-Tab>", "<<", opts)

-- <Tab> in normal mode to insert a tab
map("n", "<Tab>", "i<tab>", opts)

--------------------------------------------------------------------------------
-- Insert Mode Enhancements
--------------------------------------------------------------------------------

-- 'jj' to exit insert mode
map("i", "jj", "<Esc>", opts)

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
map("x", "<S-A-j>", ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = "Move Up (reversed)" })
map("x", "<S-A-k>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Move Down (reversed)" })

--------------------------------------------------------------------------------
-- Buffer & Window Management
--------------------------------------------------------------------------------

-- let ,q close current buffer
map("n", ",q", "<leader>bd", { remap = true, desc = "Close current buffer" })

-- let ,f format the current buffer
map("n", ",f", ":w<CR>", { desc = "(Format + Save) current buffer" })

-- use ,a to open snacks explorer
map("n", ",a", "<leader>e", { remap = true, desc = "Open snacks explorer (root dir)" })

-- use ,w and ,e to cycle windows
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
map({ "n", "x" }, "<BS>", [["_dh]], opts)
map({ "n", "x" }, "<Del>", [["_<Del>]], opts)

-- Prevent 'd', 'D' from yanking
map({ "n", "x" }, "d", [["_d]], opts)
map("n", "D", [["_D]], opts)

-- Prevent 'p' and 'P' in visual mode from yanking
map("x", "p", [["_dP]], opts)
map("x", "P", [["_dP]], opts)

-- s in visual mode substitutes the selection without yanking
map("x", "s", [["_di]], opts)

--------------------------------------------------------------------------------
-- Word Motions Customization
--------------------------------------------------------------------------------

-- w/e/b hop between alphanumeric words, skipping punctuation.
-- vim.fn.search() doesn't touch the search register, 'incsearch', or
-- 'hlsearch', so no option juggling is needed.
local word_motions = {
  w = { [[\w\+]], "b" }, -- previous word start
  e = { [[\w\+]], "" }, -- next word start
  b = { [[\w\+\>]], "e" }, -- next word end
}
for lhs, motion in pairs(word_motions) do
  map({ "n", "x" }, lhs, function()
    vim.fn.search(motion[1], motion[2])
  end, opts)
end

-- Uppercase WORD movements
map({ "n", "x" }, "W", "B", opts)
map({ "n", "x" }, "E", "W", opts)
map({ "n", "x" }, "B", "E", opts)

--------------------------------------------------------------------------------
-- Miscellaneous Utility Keymaps
--------------------------------------------------------------------------------

-- Shift+U to redo
map("n", "<S-U>", "<C-R>", opts)

-- ,d to fold under cursor
map("n", ",d", "za", { desc = "Toggle Fold Under Cursor" })

-- ,r to rename symbol under cursor
map("n", ",r", "<leader>cr", { remap = true, desc = "Rename Symbol Under Cursor" })

-- <leader>hc to inspect treesitter captures / highlights under cursor
map("n", "<leader>hc", "<cmd>Inspect<CR>", { desc = "Inspect Highlights Under Cursor" })

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

-- Remove LazyVim's default Alt+j/k line-move mappings (best-effort, in case
-- a LazyVim update changes them — a hard del would abort this whole file)
pcall(del, "n", "<A-k>")
pcall(del, "n", "<A-j>")

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

-- Wrap the visual selection in a delimiter pair (setup lives in the spec)
local wrap = require("tenaille").wrap
local delimiters = {
  ['"'] = { '"', '"' },
  ["'"] = { "'", "'" },
  ["`"] = { "`", "`" },
  ["("] = { "(", ")" },
  ["["] = { "[", "]" },
  ["{"] = { "{", "}" },
  ["<"] = { "<", ">" },
}
for lhs, pair in pairs(delimiters) do
  map("x", lhs, function()
    wrap(pair)
  end)
end
