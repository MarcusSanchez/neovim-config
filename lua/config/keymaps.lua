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
map("x", "<S-h>", "_", opts("Go to First Non-Blank Character"))
map("x", "<S-l>", "$", opts("Go to End of Line"))
-- on a closed fold these walk the drawn fold line (lua/util/foldcursor.lua)
for lhs, step in pairs({
  h = { "h", "Left" },
  l = { "l", "Right" },
  ["^"] = { "^", "Go to First Non-Blank Character" },
  ["_"] = { "_", "Go to First Non-Blank Character" },
  ["$"] = { "$", "Go to End of Line" },
  ["<S-h>"] = { "_", "Go to First Non-Blank Character" },
  ["<S-l>"] = { "$", "Go to End of Line" },
}) do
  map("n", lhs, function()
    require("util.foldcursor").motion(step[1])
  end, opts(step[2]))
end

-- Jump half page up/down with Shift+J/K
-- (up/down follow the j/k swap below: Shift+J goes up, Shift+K goes down)
map({ "n", "x" }, "<S-J>", "<C-U>", opts("Scroll Half Page Up"))
map({ "n", "x" }, "<S-K>", "<C-D>", opts("Scroll Half Page Down"))

-- Swap j and k. Without a count they move by display line (gj/gk), as
-- LazyVim's own j/k do, so a wrapped paragraph is walked screen row by
-- screen row; with a count, and for operators (dj/dk, cj/ck), by line.
map({ "n", "x" }, "j", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "Up (j/k swapped)" })
map({ "n", "x" }, "k", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "Down (j/k swapped)" })
map("o", "j", "k", opts("Up (j/k swapped)"))
map("o", "k", "j", opts("Down (j/k swapped)"))

-- ...and everywhere else vim spells "down" as j and "up" as k:
-- window focus (<C-w>j / <C-w><C-j>), window moves (<C-w>J), fold jumps
-- (zj/zk). Plugin UIs get the same treatment in their specs: snacks picker
-- <C-j>/<C-k> and terminal nav (snacks.lua), undotree J/K (undotree.lua).
map("n", "<C-w>j", "<C-w>k", opts("Go to Upper Window (j/k swapped)"))
map("n", "<C-w>k", "<C-w>j", opts("Go to Lower Window (j/k swapped)"))
map("n", "<C-w><C-j>", "<C-w>k", opts("Go to Upper Window (j/k swapped)"))
map("n", "<C-w><C-k>", "<C-w>j", opts("Go to Lower Window (j/k swapped)"))
map("n", "<C-w>J", "<C-w>K", opts("Move Window to Top (j/k swapped)"))
map("n", "<C-w>K", "<C-w>J", opts("Move Window to Bottom (j/k swapped)"))
map({ "n", "x", "o" }, "zj", "zk", opts("Previous Fold Start (j/k swapped)"))
map({ "n", "x", "o" }, "zk", "zj", opts("Next Fold Start (j/k swapped)"))

--------------------------------------------------------------------------------
-- Indentation & Tabs
--------------------------------------------------------------------------------

-- Indent/dedent the selection while keeping it selected and anchored to the
-- same text (lua/util/editing.lua)
map("x", "<Tab>", function()
  require("util.editing").shift_selection(">")
end, opts("Indent Selection (keep selection)"))
map("x", "<S-Tab>", function()
  require("util.editing").shift_selection("<")
end, opts("Dedent Selection (keep selection)"))
map("n", "<S-Tab>", "<<", opts("Dedent Line"))

-- <Tab> in normal mode to insert a tab
map("n", "<Tab>", "i<tab>", opts("Insert Tab"))

--------------------------------------------------------------------------------
-- Insert Mode Enhancements
--------------------------------------------------------------------------------

-- Leave insert mode where the insert ended instead of one column back
-- (lua/util/editing.lua): `a jj` repeated walks right, `i jj` stays put
local function leave_insert()
  return require("util.editing").leave_insert()
end
map("i", "<Esc>", leave_insert, { expr = true, desc = "Exit Insert Mode (stay put)" })
map("i", "jj", leave_insert, { expr = true, desc = "Exit Insert Mode" })

--------------------------------------------------------------------------------
-- Line Manipulation
--------------------------------------------------------------------------------

-- Shift+N collapses content (joins lines; Shift+J is the half-page scroll)
map({ "n", "x" }, "<S-N>", "J", opts("Join Lines"))

-- Remove LazyVim's default Alt+j/k line-move mappings in every mode they're
-- set (the reversed versions live on <S-A-j>/<S-A-k> below). Best-effort, in
-- case a LazyVim update changes them — a hard del would abort this whole file.
for _, mode in ipairs({ "n", "i", "v" }) do
  pcall(del, mode, "<A-k>")
  pcall(del, mode, "<A-j>")
end

-- Normal mode - move lines up and down (reversed)
-- silent! keeps the move a no-op (instead of E16) at the buffer edges
map("n", "<S-A-j>", "<cmd>execute 'silent! move .-' . (v:count1 + 1)<cr>==", opts("Move Line Up (reversed)"))
map("n", "<S-A-k>", "<cmd>execute 'silent! move .+' . v:count1<cr>==", opts("Move Line Down (reversed)"))

-- Insert mode - move lines up and down (reversed)
map("i", "<S-A-j>", "<esc><cmd>silent! m .-2<cr>==gi", opts("Move Line Up (reversed)"))
map("i", "<S-A-k>", "<esc><cmd>silent! m .+1<cr>==gi", opts("Move Line Down (reversed)"))

-- Visual mode - move lines up and down (reversed)
map(
  "x",
  "<S-A-j>",
  ":<C-u>execute \"silent! '<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv",
  { desc = "Move Lines Up (reversed)" }
)
map(
  "x",
  "<S-A-k>",
  ":<C-u>execute \"silent! '<,'>move '>+\" . v:count1<cr>gv=gv",
  { desc = "Move Lines Down (reversed)" }
)

--------------------------------------------------------------------------------
-- Pickers
--------------------------------------------------------------------------------

-- Shift+Space opens the same file picker as <leader><leader> (space space).
-- A bare double-tap of Shift can't be mapped: Neovim has no keycode for a
-- standalone modifier press, so the terminal never delivers one. <S-Space>
-- needs the kitty keyboard protocol, which Ghostty (and Neovide) support.
map("n", "<S-Space>", "<leader><space>", { remap = true, desc = "Find Files (Root Dir)" })

-- gs searches workspace symbols (like <leader>sS, minus test/generated code
-- and fuzzy over-matches — see lua/util/symbols.lua), g/ greps the project
-- (same picker as <leader>/)
map("n", "gs", function()
  require("util.symbols").search()
end, opts("Search Workspace Symbols"))
map("n", "g/", "<leader>/", { remap = true, desc = "Grep (Root Dir)" })

--------------------------------------------------------------------------------
-- Buffer & Window Management
--------------------------------------------------------------------------------

-- let ,q close current buffer
map("n", ",q", "<leader>bd", { remap = true, desc = "Close Current Buffer" })

-- let ,f format the current buffer
map("n", ",f", ":w<CR>", opts("Format + Save Current Buffer"))

-- snacks explorer sidebar (lua/util/explorer.lua; oil lives next to it on
-- `-`/`,o`, harpoon on `,h…`, neo-tree is benched in lua/benched/). ,a opens
-- it, focuses it when open, closes it when focused; ,c closes it.
map("n", ",a", function()
  require("util.explorer").toggle()
end, opts("Toggle/Focus Explorer (Root Dir)"))
map("n", ",c", function()
  require("util.explorer").close()
end, opts("Close Explorer"))

-- use ,w and ,e to cycle windows
map("n", ",w", "<C-w>h", opts("Go to Left Window"))
map("n", ",e", "<C-w>l", opts("Go to Right Window"))
map("n", "<leader>j", "<C-w>k", opts("Go to Top Window"))
map("n", "<leader>k", "<C-w>j", opts("Go to Bottom Window"))

-- use Alt + (h/l) to go forward and back buffers
map("n", "<A-h>", "<cmd>bprevious<cr>", opts("Previous Buffer"))
map("n", "<A-l>", "<cmd>bnext<cr>", opts("Next Buffer"))

--------------------------------------------------------------------------------
-- Clipboard, Delete, and Yank Behavior
--------------------------------------------------------------------------------

-- Backspace and Delete without yanking to clipboard (in visual mode the
-- selection goes, nothing more)
map("n", "<BS>", [["_dh]], opts("Backspace (No Yank)"))
map("x", "<BS>", [["_d]], opts("Delete Selection (No Yank)"))
map({ "n", "x" }, "<Del>", [["_<Del>]], opts("Delete Character (No Yank)"))

-- Prevent 'd', 'D' from yanking
map({ "n", "x" }, "d", [["_d]], opts("Delete (No Yank)"))
map("n", "D", [["_D]], opts("Delete to End of Line (No Yank)"))

-- Prevent 'p' and 'P' in visual mode from yanking
map("x", "p", [["_dP]], opts("Paste Over Selection (No Yank)"))
map("x", "P", [["_dP]], opts("Paste Over Selection (No Yank)"))

-- on a caret (a closed fold's line) x/X/r edit the character under it with
-- the fold closed, and v opens the fold to select from it (lua/util/foldcursor.lua)
for _, key in ipairs({ "x", "X", "r" }) do
  map("n", key, function()
    require("util.foldcursor").edit(key)
  end, opts(({ x = "Delete Character", X = "Delete Character Before", r = "Replace Character" })[key]))
end
map("n", "v", function()
  require("util.foldcursor").visual()
end, opts("Visual Mode"))

-- gc on a selection within a line: a block comment around it, IntelliJ
-- style (lua/util/comment.lua); linewise selections stay line comments
map("x", "gc", function()
  return require("util.comment").operator()
end, { expr = true, desc = "Toggle Comment (block within a line)" })

-- s in visual mode substitutes the selection without yanking (this is the
-- one mode flash's `s` doesn't get; flash keeps o, and in normal mode its
-- jump goes through util/goto so gh comes back from it)
map("x", "s", [["_di]], opts("Substitute Selection (No Yank)"))
map("n", "s", function()
  require("util.goto").flash()
end, opts("Flash"))

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
-- In normal mode they go through the fold caret: on a closed fold the
-- same search runs over the drawn fold line (lua/util/foldcursor.lua).
for lhs, motion in pairs(word_motions) do
  local function run()
    vim.fn.search(motion[1], motion[2])
  end
  map("x", lhs, run, opts(motion[3]))
  map("n", lhs, function()
    require("util.foldcursor").motion(lhs, run)
  end, opts(motion[3]))
end

-- Uppercase WORD movements (through the fold caret in normal mode too)
for lhs, motion in pairs({
  W = { "B", "Previous WORD Start" },
  E = { "W", "Next WORD Start" },
  B = { "E", "Next WORD End" },
}) do
  map("x", lhs, motion[1], opts(motion[2]))
  map("n", lhs, function()
    require("util.foldcursor").motion(motion[1])
  end, opts(motion[2]))
end

--------------------------------------------------------------------------------
-- Miscellaneous Utility Keymaps
--------------------------------------------------------------------------------

-- Shift+U to redo
map("n", "<S-U>", "<C-R>", opts("Redo"))

-- search motions reveal a match inside a closed fold only for the visit
-- (lua/util/searchfolds.lua); n follows the search direction as in LazyVim.
-- N is not a search key here: Shift-N joins lines (above)
for _, key in ipairs({ "n", "*", "#" }) do
  map("n", key, function()
    require("util.searchfolds").motion(key)
  end, { desc = ({ n = "Next Search Match", ["*"] = "Search Word Forward", ["#"] = "Search Word Backward" })[key] })
end

-- ,d folds the region at the cursor the way JetBrains does (an if branch,
-- its else, wrapped parameters: each on its own), or opens the fold there
-- (lua/util/foldranges.lua)
map("n", ",d", function()
  require("util.foldranges").toggle()
  require("util.foldcursor").refresh() -- a fold closed around the cursor gets the caret
end, opts("Toggle Fold Under Cursor"))

-- ,r to rename symbol under cursor
map("n", ",r", "<leader>cr", { remap = true, desc = "Rename Symbol Under Cursor" })

-- ,r in visual mode renames too: drop to normal mode, then reuse the map above
map("x", ",r", "<Esc>,r", { remap = true, desc = "Rename Symbol Under Cursor" })

-- <leader>hc to inspect treesitter captures / highlights under cursor
map("n", "<leader>hc", "<cmd>Inspect<CR>", opts("Inspect Highlights Under Cursor"))

--------------------------------------------------------------------------------
-- LSP & Diagnostics
--------------------------------------------------------------------------------

-- (gk hover is an LSP key in plugins/lsp.lua, next to the disabled K)

-- <Esc> keeps LazyVim's behaviour (clear hlsearch, stop snippet) and also
-- dismisses the gk hover / signature docs and the ge float (lua/util/popup.lua)
map("n", "<Esc>", function()
  return require("util.popup").escape()
end, { expr = true, desc = "Escape, Clear hlsearch, Dismiss Popups" })

-- ge opens the line's diagnostics in a float styled like the gk hover
map("n", "ge", function()
  require("util.popup").diagnostics()
end, opts("Show Diagnostics (Float)"))

-- make ,g open code actions
map("n", ",g", "<leader>ca", { remap = true, desc = "Code Actions" })

--------------------------------------------------------------------------------
-- Text Wrapping (tenaille.nvim)
--------------------------------------------------------------------------------

-- Wrap the visual selection in a delimiter pair (setup lives in the spec).
-- `<` here replaces visual dedent, which lives on <S-Tab> above.
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
