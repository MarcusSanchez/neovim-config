-- fold shapes: Lua with lua_ls (tests/fixtures/lua): keyword blocks — a function stops a line short of its `end`, branches before `elseif`/`else`/`end` — and the usual brackets.
local lib = dofile(debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]*$") .. "/lib.lua")
lib.suite("lua_ls", function(t)
  t.shape(9, "8..11", "--[[ ... ]]")
  t.shape(13, "12..18", "local config = { ... }")
  t.shape(15, "14..17", "  items = { ... },")
  t.shape(20, "20..28", "function M.run(a, b) ... end")
  t.shape(22, "21..23", "  if a > b then ... elseif a == b then")
  t.shape(24, "23..25", "  elseif a == b then ... else")
  t.shape(26, "25..27", "  else ... end")
  t.fold(24) -- the elseif over the folded else: their chain
  t.check(
    "folding the elseif over the folded else: their chain",
    t.span(23) .. " " .. vim.fn.foldtextresult(23),
    "23..27   elseif a == b then ... else ... end"
  )
  t.fold(22) -- and the if over that: the whole statement
  t.check(
    "the if over the folded chain: the whole if",
    t.span(21) .. " " .. vim.fn.foldtextresult(21),
    "21..27   if a > b then ... elseif a == b then ... else ... end"
  )
  t.shape(30, "30..40", "local function each(list) ... end")
  t.shape(32, "31..33", "  for i, v in ipairs(list) do ... end")
  t.shape(35, "34..36", "  while false do ... end")
  t.shape(38, "37..39", "  repeat ... until true")
  t.shape(43, "42..54", "M.handler = function( ... ) ... end")
  t.shape(51, "50..53", "  return fs.read([[ ... ]])")
end)
