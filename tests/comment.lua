-- gc on a selection within a line wraps it in a block comment
-- (lua/util/comment.lua); linewise and gcc stay line comments; languages
-- without block comments fall back to the line comment.
local logf = io.open(vim.fn.getcwd() .. "/result.log", "w")
local function log(s)
  logf:write(s, "\n")
  logf:flush()
end
local function check(name, got, want)
  log(("%s %s: %s (want %s)"):format(got == want and "PASS" or "FAIL", name, tostring(got), tostring(want)))
end
vim.defer_fn(function()
  log("TIMEOUT")
  vim.cmd("qall!")
end, 60000)
vim.schedule(function()
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    local function keys(k)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(k, true, false, true), "x", false)
    end
    local function select(sl, sc, el, ec) -- 1-based lines, 0-based byte columns
      vim.api.nvim_win_set_cursor(0, { sl, sc })
      vim.cmd("normal! v")
      vim.api.nvim_win_set_cursor(0, { el, ec })
    end
    local function buffer(ft, lines)
      local b = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_set_current_buf(b)
      vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
      vim.bo[b].filetype = ft
      return b
    end
    buffer("go", { "\tx := foo(bar, baz)", "\ty := 1" })
    select(1, 10, 1, 12)
    keys("gc")
    check("gc on a selection: a block comment around it", vim.fn.getline(1), "\tx := foo(/* bar */, baz)")
    check("cursor at the comment", vim.fn.line(".") .. ":" .. vim.fn.col("."), "1:11")
    check("back in normal mode", vim.api.nvim_get_mode().mode, "n")
    select(1, 10, 1, 18)
    keys("gc")
    check("gc on the comment: unwrapped", vim.fn.getline(1), "\tx := foo(bar, baz)")
    vim.cmd("normal! 1GV")
    keys("gc")
    check("linewise gc: a line comment", vim.fn.getline(1), "\t// x := foo(bar, baz)")
    vim.cmd("normal! 2G")
    keys("gcc")
    check("gcc: a line comment", vim.fn.getline(2), "\t// y := 1")
    -- a selection across lines
    buffer("go", { "a(", "\t1,", ")" })
    select(1, 0, 2, 2)
    keys("gc")
    check(
      "across lines: opened on the first, closed on the last",
      table.concat(vim.fn.getline(1, 3), "|"),
      "/* a(|\t1, */|)"
    )
    -- no block comment in the language: the line comment as before
    buffer("zig", { "const x = foo(bar);" })
    select(1, 14, 1, 16)
    keys("gc")
    check("zig: the line comment", vim.fn.getline(1), "// const x = foo(bar);")
    -- JSX markup takes `{/* */}`, code inside it `/* */`
    buffer(
      "typescriptreact",
      { "const a = 1;", "const b = (", "  <div>", "    hello there", "    {a + 1}", "  </div>", ");" }
    )
    select(4, 4, 4, 8)
    keys("gc")
    check("in JSX text", vim.fn.getline(4), "    {/* hello */} there")
    select(5, 5, 5, 5)
    keys("gc")
    check("in a JSX expression", vim.fn.getline(5), "    {/* a */ + 1}")
    select(1, 6, 1, 6)
    keys("gc")
    check("in plain code", vim.fn.getline(1), "const /* a */ = 1;")
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
