-- fold shapes with clangd on C (tests/fixtures/c): clangd stops a line
-- short of every closer, including a block comment's ` */`, and folds no
-- `#include` run or preprocessor conditional — treesitter supplies those
-- (see util/foldranges.lua's supplements).
local lib = dofile(debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]*$") .. "/lib.lua")
lib.suite("clangd", function(t)
  t.check("the #include run folds on open", t.span(2), "1..3")
  t.check("include run fold line", vim.fn.foldtextresult(1), "#include ...")
  t.check("the rest of the file is open", vim.fn.foldclosed(9), -1)
  t.shape(6, "5..8", "/* ... */")
  t.shape(10, "9..12", "struct node { ... };")
  t.shape(15, "14..17", "enum color { ... };")
  t.shape(20, "19..23", "static const int table[] = { ... };")
  -- a wrapped signature: parameters and body fold apart
  vim.cmd("normal! zR")
  t.fold(26)
  t.check("wrapped parameters fold on their own", t.span(26), "25..28")
  t.check("parameters fold line", vim.fn.foldtextresult(25), "static int insert( ... ) {")
  t.fold(26)
  t.fold(29)
  t.check("the body folds from the `) {` line", t.span(29), "28..70")
  t.check("body fold line", vim.fn.foldtextresult(28), ") { ... }")
  t.check("the parameters stay open above it", vim.fn.foldclosed(25), -1)
  t.fold(26)
  t.check("parameters over a folded body: the whole function", t.span(26), "25..70")
  t.check("whole-function fold line", vim.fn.foldtextresult(25), "static int insert( ... ) { ... }")
  -- an if / else if / else chain: each branch its own fold
  vim.cmd("normal! zR")
  t.fold(35)
  t.check("an if branch folds to its `} else if`", t.span(35), "34..36")
  t.check(
    "if fold line",
    vim.fn.foldtextresult(34),
    "    if (*head == NULL) { ... } else if (value < (*head)->value) {"
  )
  vim.cmd("normal! zR")
  t.fold(37)
  t.check("an else-if branch folds to its `} else {`", t.span(37), "36..39")
  t.check("else-if fold line", vim.fn.foldtextresult(36), "    } else if (value < (*head)->value) { ... } else {")
  t.fold(40)
  t.check("the else over a folded else-if: their chain", t.span(36), "36..42")
  t.check("the if branch above stays open", vim.fn.foldclosed(34), -1)
  t.fold(35)
  t.check("the if over the folded chain: the whole chain", t.span(34), "34..42")
  t.check(
    "whole chain fold line",
    vim.fn.foldtextresult(34),
    "    if (*head == NULL) { ... } else if (value < (*head)->value) { ... } else { ... }"
  )
  t.shape(44, "43..51", "    switch (value) { ... }")
  t.shape(48, "47..50", "    default: { ... }")
  t.shape(53, "52..54", "    for (int i = 0; i < value; i++) { ... }")
  t.shape(56, "55..57", "    while (value > 0) { ... }")
  t.shape(59, "58..60", "    do { ... } while (value < 3);")
  t.shape(62, "61..65", "    printf( ... );")
  t.shape(67, "66..68", "#ifdef DEBUG ... #endif")
  t.shape(73, "72..76", "int main(void) { ... }")
end)
