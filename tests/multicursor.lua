-- Multiple cursors (lua/util/multicursor.lua) over Neovim's own: the
-- Alt-Shift keys gather matches of the word under the cursor or of the
-- selection, Ctrl-j/k gather lines, edits replay at every cursor, Esc
-- clears. On the Go fixture, no server needed. The cursors replay on real
-- input only, so the checks run as a chain of steps between keystrokes.
local lib = dofile(debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]*$") .. "/lib.lua")
local t = lib.open(vim.fn.expand("%:p:h") .. "/result.log")
vim.defer_fn(function()
  t.log("TIMEOUT")
  vim.cmd("qall!")
end, 60000)
vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" }) -- the config's keymaps
local MC = require("util.multicursor")
local buf = vim.api.nvim_get_current_buf()
local function input(k) -- key notation as is: nvim_input reads it like the terminal's
  vim.api.nvim_input(k)
end
local function cursors()
  local out = {}
  for _, m in ipairs(MC.cursors(buf)) do
    out[#out + 1] = (m[2] + 1) .. ":" .. m[3]
  end
  return table.concat(out, " ")
end
local function primary()
  local c = vim.api.nvim_win_get_cursor(0)
  return c[1] .. ":" .. c[2]
end
local function lines(...)
  local out = {}
  for _, l in ipairs({ ... }) do
    out[#out + 1] = vim.api.nvim_buf_get_lines(buf, l - 1, l, false)[1]
  end
  return table.concat(out, " | ")
end
local steps = {}
local function step(f)
  steps[#steps + 1] = f
end
local function run(i)
  if not steps[i] then
    t.log("DONE")
    return vim.cmd("qall!")
  end
  local ok, err = pcall(steps[i])
  if not ok then
    t.log("ERROR: " .. tostring(err))
    return vim.cmd("qall!")
  end
  vim.defer_fn(function()
    run(i + 1)
  end, 250)
end
-- main.go (tab-indented): 3 `func foobar() {}`, 5 `func multi() {}`,
-- 10 `foobar()`, 11 `multi()`, 12 `multi()`
step(function()
  t.check("no cursors to begin with", MC.active(buf), false)
  vim.api.nvim_win_set_cursor(0, { 5, 5 }) -- `multi` in its declaration
  input("<M-S-l>")
end)
step(function()
  t.check(
    "Alt-Shift-l: a cursor left here, the primary on the next `multi`",
    cursors() .. " / " .. primary(),
    "5:5 / 11:1"
  )
  t.check("the word is the search pattern (hlsearch shows the rest)", vim.fn.getreg("/"), [[\V\<multi\>]])
  input("<M-S-l>")
end)
step(function()
  t.check("again: two cursors, the primary on the last `multi`", cursors() .. " / " .. primary(), "5:5 11:1 / 12:1")
  input("<M-S-s>")
end)
step(function()
  t.check("skip with every match taken: the primary stays", cursors() .. " / " .. primary(), "5:5 11:1 / 12:1")
  input("<M-S-h>")
end)
step(function()
  t.check("Alt-Shift-h: the last cursor let go, the primary back on it", cursors() .. " / " .. primary(), "5:5 / 11:1")
  input("<M-S-l>")
end)
step(function()
  t.check("gathered again", cursors() .. " / " .. primary(), "5:5 11:1 / 12:1")
  t.check("the cursors follow the primary", vim.bo.follow, true)
  input("l") -- the caret's l: a plain key while cursors stand, so it replays
end)
step(function()
  t.check("l moves every cursor", cursors() .. " / " .. primary(), "5:6 11:2 / 12:2")
  input("x")
end)
step(function()
  t.check("x edits at every cursor", lines(5, 11, 12), "func mlti() {} | \tmlti() | \tmlti()")
  input("u")
end)
step(function()
  t.check("undone", lines(5, 11, 12), "func multi() {} | \tmulti() | \tmulti()")
  input("w") -- the config's own w (a search in Lua): run at each cursor in turn
end)
step(function()
  t.check("w moves every cursor to its previous word start", cursors() .. " / " .. primary(), "5:5 11:1 / 12:1")
  input("ciwmany<Esc>")
end)
step(function()
  t.check("an edit replays at every cursor", lines(5, 11, 12), "func many() {} | \tmany() | \tmany()")
  t.check("the cursors stand", #MC.cursors(buf), 2)
  input("u")
end)
step(function()
  t.check("one undo reverts all of it", lines(5, 11, 12), "func multi() {} | \tmulti() | \tmulti()")
  input("<Right>")
end)
step(function()
  t.check("Right walks to the next cursor", primary(), "5:5")
  input("<Esc>")
end)
step(function()
  t.check("Esc clears the cursors", cursors(), "")
  -- a selection: `foobar` on line 10, then its other occurrence
  vim.api.nvim_win_set_cursor(0, { 10, 4 })
  input("viw<M-S-l>")
end)
step(function()
  t.check(
    "from a selection: a cursor at its start, the match selected at the primary",
    cursors() .. " / " .. vim.fn.mode() .. " " .. primary(),
    "10:1 / v 3:10"
  )
  input("cmany<Esc>")
end)
step(function()
  t.check("changing the selection changes the match at every cursor", lines(3, 10), "func many() {} | \tmany()")
  input("u")
end)
step(function()
  t.check("undone", lines(3, 10), "func foobar() {} | \tfoobar()")
  input("<Esc>")
  vim.api.nvim_win_set_cursor(0, { 12, 4 }) -- inside `multi`
  input("<M-S-n>")
end)
step(function()
  t.check(
    "Alt-Shift-n: the cursor at the word's start, the primary on the previous match",
    cursors() .. " / " .. primary(),
    "12:1 / 11:1"
  )
  input("<M-S-b>")
end)
step(function()
  t.check("Alt-Shift-b: skip back to the one before", cursors() .. " / " .. primary(), "12:1 / 5:5")
  input("<M-S-h>")
end)
step(function()
  t.check("letting the only cursor go", cursors() .. " / " .. primary(), " / 12:1")
  -- lines: a cursor on 10 and 11, the primary on 12
  vim.api.nvim_win_set_cursor(0, { 10, 4 })
  input("<C-k><C-k>")
end)
step(function()
  t.check(
    "Ctrl-k twice: cursors on the two lines above the primary",
    cursors() .. " / " .. primary(),
    "10:4 11:4 / 12:4"
  )
  input("A // x<Esc>")
end)
step(function()
  t.check("appending replays on each line", lines(10, 11, 12), "\tfoobar() // x | \tmulti() // x | \tmulti() // x")
  input("u")
end)
step(function()
  t.check("undone", lines(10, 12), "\tfoobar() | \tmulti()")
  input("<Esc>")
end)
step(function()
  t.check("cleared", MC.active(buf), false)
end)
vim.schedule(function()
  run(1)
end)
