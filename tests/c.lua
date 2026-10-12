-- fold shapes with clangd on C (tests/fixtures/c): clangd stops a line
-- short of every closer, including a block comment's ` */`, and folds no
-- `#include` run or preprocessor conditional — treesitter supplies those
-- (see util/foldranges.lua's supplements).
local dir = vim.fn.expand("%:p:h")
local logf = io.open(dir .. "/result.log", "w")
local function log(s)
  logf:write(s, "\n")
  logf:flush()
end
local function wait(ms)
  vim.wait(ms, function()
    return false
  end)
end
local function check(name, got, want)
  log(("%s %s: %s (want %s)"):format(got == want and "PASS" or "FAIL", name, tostring(got), tostring(want)))
end
vim.defer_fn(function()
  log("TIMEOUT")
  vim.cmd("qall!")
end, 120000)
vim.schedule(function()
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    vim.o.lines, vim.o.columns = 40, 120
    vim.wait(30000, function()
      return #vim.lsp.get_clients({ bufnr = 0, name = "clangd" }) > 0
    end, 100)
    local FR = require("util.foldranges")
    vim.wait(15000, function()
      return FR.has(0)
    end, 50)
    wait(300)
    check("folds come from clangd", FR.has(0), true)
    local function fold(l) -- ,d on line l
      vim.cmd(("normal! %dG"):format(l))
      FR.toggle()
    end
    local function span(l)
      return vim.fn.foldclosed(l) .. ".." .. vim.fn.foldclosedend(l)
    end
    local function shape(l, want_span, want_text)
      vim.cmd("normal! zR")
      fold(l)
      local s = vim.fn.foldclosed(l)
      check("fold at " .. l, span(l) .. " " .. vim.fn.foldtextresult(s), want_span .. " " .. want_text)
    end
    check("the #include run folds on open", span(2), "1..3")
    check("include run fold line", vim.fn.foldtextresult(1), "#include ...")
    check("the rest of the file is open", vim.fn.foldclosed(9), -1)
    shape(6, "5..8", "/* ... */")
    shape(10, "9..12", "struct node { ... };")
    shape(15, "14..17", "enum color { ... };")
    shape(20, "19..23", "static const int table[] = { ... };")
    -- a wrapped signature: parameters and body fold apart
    vim.cmd("normal! zR")
    fold(26)
    check("wrapped parameters fold on their own", span(26), "25..28")
    check("parameters fold line", vim.fn.foldtextresult(25), "static int insert( ... ) {")
    fold(26)
    fold(29)
    check("the body folds from the `) {` line", span(29), "28..70")
    check("body fold line", vim.fn.foldtextresult(28), ") { ... }")
    check("the parameters stay open above it", vim.fn.foldclosed(25), -1)
    fold(26)
    check("parameters over a folded body: the whole function", span(26), "25..70")
    check("whole-function fold line", vim.fn.foldtextresult(25), "static int insert( ... ) { ... }")
    -- an if / else if / else chain: each branch its own fold
    vim.cmd("normal! zR")
    fold(35)
    check("an if branch folds to its `} else if`", span(35), "34..36")
    check(
      "if fold line",
      vim.fn.foldtextresult(34),
      "    if (*head == NULL) { ... } else if (value < (*head)->value) {"
    )
    vim.cmd("normal! zR")
    fold(37)
    check("an else-if branch folds to its `} else {`", span(37), "36..39")
    check("else-if fold line", vim.fn.foldtextresult(36), "    } else if (value < (*head)->value) { ... } else {")
    fold(40)
    check("the else over a folded else-if: their chain", span(36), "36..42")
    check("the if branch above stays open", vim.fn.foldclosed(34), -1)
    fold(35)
    check("the if over the folded chain: the whole chain", span(34), "34..42")
    check(
      "whole chain fold line",
      vim.fn.foldtextresult(34),
      "    if (*head == NULL) { ... } else if (value < (*head)->value) { ... } else { ... }"
    )
    shape(44, "43..51", "    switch (value) { ... }")
    shape(48, "47..50", "    default: { ... }")
    shape(53, "52..54", "    for (int i = 0; i < value; i++) { ... }")
    shape(56, "55..57", "    while (value > 0) { ... }")
    shape(59, "58..60", "    do { ... } while (value < 3);")
    shape(62, "61..65", "    printf( ... );")
    shape(67, "66..68", "#ifdef DEBUG ... #endif")
    shape(73, "72..76", "int main(void) { ... }")
    vim.cmd("normal! zR")
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
