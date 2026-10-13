-- fold shapes with the gleam language server (tests/fixtures/gleam): it
-- folds only top-level declarations, and a wrapped signature from its `)`
-- line, so treesitter supplies the bracket regions inside (see
-- util/foldranges.lua's supplements).
local lib = dofile(debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]*$") .. "/lib.lua")
lib.suite("gleam", function(t)
  t.check("imports fold on open", t.span(2), "1..4")
  t.check("imports fold line", vim.fn.foldtextresult(1), "import ...")
  t.check("the rest of the file is open", vim.fn.foldclosed(6), -1)
  vim.cmd("normal! zR")
  t.fold(7)
  t.check("a custom type", vim.fn.foldtextresult(6), "pub type Shape { ... }")
  t.fold(14)
  t.check(
    "a wrapped constructor's fields (treesitter)",
    t.span(14) .. " " .. vim.fn.foldtextresult(13),
    "13..17   Node( ... )"
  )
  t.fold(22)
  t.check(
    "a case expression (treesitter)",
    t.span(22) .. " " .. vim.fn.foldtextresult(21),
    "21..27   case shape { ... }"
  )
  vim.cmd("normal! zR")
  t.fold(24)
  t.check("a clause's block", vim.fn.foldtextresult(23), "    Rect(width, height) -> { ... }")
  vim.cmd("normal! zR")
  -- the server's range for a wrapped signature starts on its `)` line;
  -- treesitter's function node gives the whole, so it folds like Go's
  t.fold(31)
  t.check("wrapped parameters fold on their own", t.span(31), "30..33")
  t.check("parameters fold line", vim.fn.foldtextresult(30), "pub fn insert( ... ) -> Tree(Int) {")
  t.fold(31) -- open them again
  t.fold(33)
  t.check("the body folds from the `) -> Tree(Int) {` line", t.span(33), "33..45")
  t.check("body fold line", vim.fn.foldtextresult(33), ") -> Tree(Int) { ... }")
  t.check("the parameters stay open above it", vim.fn.foldclosed(30), -1)
  t.fold(31)
  t.check("parameters over a folded body: the whole function", t.span(31), "30..45")
  t.check("whole-function fold line", vim.fn.foldtextresult(30), "pub fn insert( ... ) -> Tree(Int) { ... }")
  vim.cmd("normal! zR")
  t.fold(40)
  t.check("a nested case clause block", vim.fn.foldtextresult(39), "        False -> { ... }")
  vim.cmd("normal! zR")
  t.fold(51)
  t.check("an anonymous function in a pipeline", vim.fn.foldtextresult(50), "    |> list.map(fn(x) { ... })")
  vim.cmd("normal! zR")
  t.fold(55)
  t.check("a list literal", vim.fn.foldtextresult(54), "  let names = [ ... ]")
  vim.cmd("normal! zR")
  t.fold(60)
  t.check("wrapped arguments", vim.fn.foldtextresult(59), "  let message = int.to_string( ... )")
  vim.cmd("normal! zR")
  t.fold(64)
  t.check("a case over a list", vim.fn.foldtextresult(63), "  case names { ... }")
  vim.cmd("normal! zR")
  t.fold(76)
  t.check("a doc comment run", vim.fn.foldtextresult(76), "/// Documentation line one ...")
  vim.cmd("normal! zR")
  t.fold(92)
  t.check("a record update", vim.fn.foldtextresult(91), "    Config( ... )")
  vim.cmd("normal! zR")
  t.fold(96)
  t.check("a tuple", vim.fn.foldtextresult(95), "  let pair = #( ... )")
  vim.cmd("normal! zR")
  t.fold(100)
  t.check("a bit array closes with `>>`", vim.fn.foldtextresult(99), "  let bits = << ... >>")
  vim.cmd("normal! zR")
  t.fold(105)
  t.check("an anonymous function's wrapped parameters", vim.fn.foldtextresult(104), "  let add = fn( ... ) {")
  t.fold(108)
  t.check("its body from the `) {` line", vim.fn.foldtextresult(107), "  ) { ... }")
end)
