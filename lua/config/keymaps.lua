-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
-- NOTE: visual-mode maps use "x" (visual only), not "v" (visual + select),
-- so that typing over a snippet placeholder in select mode still inserts text.
--
-- NOTE: every mapping carries a `desc` so it shows up in which-key and in the
-- <leader>sk keymap picker, which is the searchable cheat sheet for this config.

local map = vim.keymap.set
local del = vim.keymap.del

-- Shared map options plus a description.
local function opts(desc)
  return { noremap = true, silent = true, desc = desc }
end

--------------------------------------------------------------------------------
-- Navigation
--------------------------------------------------------------------------------

-- Jump to start/end of line with Shift+H/L
map({ "n", "x" }, "<S-h>", "_", opts("Go to First Non-Blank Character"))
map({ "n", "x" }, "<S-l>", "$", opts("Go to End of Line"))

-- Jump half page up/down with Shift+J/K
-- (up/down follow the j/k swap below: Shift+J goes up, Shift+K goes down)
map({ "n", "x" }, "<S-J>", "<C-U>", opts("Scroll Half Page Up"))
map({ "n", "x" }, "<S-K>", "<C-D>", opts("Scroll Half Page Down"))

-- Swap j and k in normal, visual, and operator-pending mode
-- (operator-pending covers dj/dk, cj/ck, etc. — no separate swaps needed)
map({ "n", "x", "o" }, "j", "k", opts("Up (j/k swapped)"))
map({ "n", "x", "o" }, "k", "j", opts("Down (j/k swapped)"))

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
end, opts("Indent Selection (keep selection)"))
map("x", "<S-Tab>", function()
  shift_selection("<")
end, opts("Dedent Selection (keep selection)"))
map("n", "<S-Tab>", "<<", opts("Dedent Line"))

-- <Tab> in normal mode to insert a tab
map("n", "<Tab>", "i<tab>", opts("Insert Tab"))

--------------------------------------------------------------------------------
-- Insert Mode Enhancements
--------------------------------------------------------------------------------

-- 'jj' to exit insert mode
map("i", "jj", "<Esc>", opts("Exit Insert Mode"))

--------------------------------------------------------------------------------
-- Line Manipulation
--------------------------------------------------------------------------------

-- Shift+N collapses content (joins lines)
map("n", "<S-N>", "J", opts("Join Lines"))

-- Normal mode - move lines up and down (reversed)
-- silent! keeps the move a no-op (instead of E16) at the buffer edges
map("n", "<S-A-j>", "<cmd>execute 'silent! move .-' . (v:count1 + 1)<cr>==", { desc = "Move Line Up (reversed)" })
map("n", "<S-A-k>", "<cmd>execute 'silent! move .+' . v:count1<cr>==", { desc = "Move Line Down (reversed)" })

-- Insert mode - move lines up and down (reversed)
map("i", "<S-A-j>", "<esc><cmd>silent! m .-2<cr>==gi", { desc = "Move Line Up (reversed)" })
map("i", "<S-A-k>", "<esc><cmd>silent! m .+1<cr>==gi", { desc = "Move Line Down (reversed)" })

-- Visual mode - move lines up and down (reversed)
map("x", "<S-A-j>", ":<C-u>execute \"silent! '<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = "Move Lines Up (reversed)" })
map("x", "<S-A-k>", ":<C-u>execute \"silent! '<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Move Lines Down (reversed)" })

--------------------------------------------------------------------------------
-- Pickers
--------------------------------------------------------------------------------

-- Shift+Space opens the same file picker as <leader><leader> (space space).
-- A bare double-tap of Shift can't be mapped: Neovim has no keycode for a
-- standalone modifier press, so the terminal never delivers one. <S-Space>
-- needs the kitty keyboard protocol, which Ghostty (and Neovide) support.
map("n", "<S-Space>", "<leader><space>", { remap = true, desc = "Find Files (Root Dir)" })

-- gS searches workspace symbols (like <leader>sS, but skipping generated
-- files), g/ greps the project (same picker as <leader>/)
local generated_files = {
  "%.pb%.go$",
  "%.connect%.go$",
  "%.gen%.go$",
  "_gen%.go$",
  "_generated%.go$",
  "/gen/",
  "/node_modules/",
  "/ent/",
  "_test%.go$",
  "%.test%.[jt]sx?$",
  "%.spec%.[jt]sx?$",
}
-- handwritten islands inside otherwise-generated trees
local handwritten_files = {
  "/ent/schema/",
}
map("n", "gS", function()
  Snacks.picker.lsp_workspace_symbols({
    transform = function(item)
      if not item.file then
        return
      end
      for _, pat in ipairs(handwritten_files) do
        if item.file:match(pat) then
          return
        end
      end
      for _, pat in ipairs(generated_files) do
        if item.file:match(pat) then
          return false
        end
      end
    end,
  })
end, { desc = "Search Workspace Symbols" })
map("n", "g/", "<leader>/", { remap = true, desc = "Grep (Root Dir)" })

--------------------------------------------------------------------------------
-- Buffer & Window Management
--------------------------------------------------------------------------------

-- let ,q close current buffer
map("n", ",q", "<leader>bd", { remap = true, desc = "Close Current Buffer" })

-- let ,f format the current buffer
map("n", ",f", ":w<CR>", { desc = "Format + Save Current Buffer" })

-- (the snacks explorer sidebar is back — 2026-08-13, oil/harpoon benched;
-- their specs sit commented in lua/plugins/oil.lua and harpoon.lua.)

-- Returns the open explorer picker on this tab, or nil when it's closed.
local function get_explorer()
  local explorer = Snacks.picker.get({ source = "explorer" })[1]
  if explorer and not explorer.closed then
    return explorer
  end
end

-- ,a opens the snacks explorer; if it's already open it focuses it, and if it's
-- already focused it closes it.
map("n", ",a", function()
  local explorer = get_explorer()
  if not explorer then
    Snacks.explorer({ cwd = LazyVim.root() })
  elseif explorer:is_focused() then
    explorer:close()
  else
    explorer:focus()
  end
end, { desc = "Toggle/Focus Explorer (Root Dir)" })

-- ,c closes the explorer (no-op when it's already closed)
map("n", ",c", function()
  local explorer = get_explorer()
  if explorer then
    explorer:close()
  end
end, { desc = "Close Explorer" })

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
map({ "n", "x" }, "<BS>", [["_dh]], opts("Backspace (No Yank)"))
map({ "n", "x" }, "<Del>", [["_<Del>]], opts("Delete Character (No Yank)"))

-- Prevent 'd', 'D' from yanking
map({ "n", "x" }, "d", [["_d]], opts("Delete (No Yank)"))
map("n", "D", [["_D]], opts("Delete to End of Line (No Yank)"))

-- Prevent 'p' and 'P' in visual mode from yanking
map("x", "p", [["_dP]], opts("Paste Over Selection (No Yank)"))
map("x", "P", [["_dP]], opts("Paste Over Selection (No Yank)"))

-- s in visual mode substitutes the selection without yanking
map("x", "s", [["_di]], opts("Substitute Selection (No Yank)"))

--------------------------------------------------------------------------------
-- Word Motions Customization
--------------------------------------------------------------------------------

-- w/e/b hop between alphanumeric words, skipping punctuation.
-- vim.fn.search() doesn't touch the search register, 'incsearch', or
-- 'hlsearch', so no option juggling is needed.
local word_motions = {
  w = { [[\w\+]], "b", "Previous Word Start (skip punctuation)" },
  e = { [[\w\+]], "", "Next Word Start (skip punctuation)" },
  b = { [[\w\+\>]], "e", "Next Word End (skip punctuation)" },
}
for lhs, motion in pairs(word_motions) do
  map({ "n", "x" }, lhs, function()
    vim.fn.search(motion[1], motion[2])
  end, opts(motion[3]))
end

-- Uppercase WORD movements
map({ "n", "x" }, "W", "B", opts("Previous WORD Start"))
map({ "n", "x" }, "E", "W", opts("Next WORD Start"))
map({ "n", "x" }, "B", "E", opts("Next WORD End"))

--------------------------------------------------------------------------------
-- Miscellaneous Utility Keymaps
--------------------------------------------------------------------------------

-- Shift+U to redo
map("n", "<S-U>", "<C-R>", opts("Redo"))

-- ,d to fold under cursor
map("n", ",d", "za", { desc = "Toggle Fold Under Cursor" })

-- ,r to rename symbol under cursor
map("n", ",r", "<leader>cr", { remap = true, desc = "Rename Symbol Under Cursor" })

-- ,r in visual mode renames too: drop to normal mode, then reuse the map above
map("x", ",r", "<Esc>,r", { remap = true, desc = "Rename Symbol Under Cursor" })

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
end, { desc = "Show Diagnostics (Float)" })

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
end, { desc = "Add Cursor Above" })
map({ "n", "x" }, "<C-k>", function()
  mc.lineAddCursor(1, { skipEmpty = false })
end, { desc = "Add Cursor Below" })

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
  end, { desc = "Wrap Selection in " .. pair[1] .. pair[2] })
end
