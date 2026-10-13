-- The Rust suite: the noise checker, gs symbol filtering, italics, and
-- fold shapes with rust-analyzer (tests/fixtures/rust).
local lib = dofile(debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]*$") .. "/lib.lua")
lib.suite("rust-analyzer", function(t)
  local dir = vim.fn.expand("%:p:h:h")
  local is_noise = require("util.noise").checker()
  local f = dir .. "/src/lib.rs"
  local res = {}
  for _, c in ipairs({ { 1, 7, false }, { 7, 0, true }, { 8, 3, true }, { 11, 4, true }, { 14, 7, true } }) do
    res[#res + 1] = tostring(is_noise(f, c[1], c[2]) == c[3])
  end
  t.log("noise checks all OK: " .. table.concat(res, ","))
  local function client()
    return vim.lsp.get_clients({ bufnr = 0, name = "rust-analyzer" })[1]
  end
  vim.wait(60000, function()
    return client() ~= nil
  end, 200)
  local c = assert(client(), "rust-analyzer never attached")
  vim.wait(60000, function()
    local r = c:request_sync("workspace/symbol", { query = "foobar" }, 5000, 0)
    return r and r.result and #r.result > 0
  end, 1000)
  vim.fn.maparg("gs", "n", false, true).callback()
  local function symbols_picker() -- not the explorer, which is a picker too
    return Snacks.picker.get({ source = "lsp_workspace_symbols" })[1]
  end
  vim.wait(2000, function()
    return symbols_picker() ~= nil
  end, 50)
  local p = assert(symbols_picker(), "no picker")
  vim.wait(10000, function() -- the picker's own first search, before the query
    return not p.finder:running()
  end, 100)
  p.input:set("", "foobar")
  -- rust-analyzer drops an in-flight workspace/symbol while it reloads
  -- after a watched-file change, which happens just after it starts: a
  -- search that comes back empty is run again, as a person would
  for _ = 1, 3 do
    p:find({ refresh = true })
    vim.wait(10000, function()
      return not p.finder:running() and p:count() > 0
    end, 100)
    if p:count() > 0 then
      break
    end
    vim.wait(1000, function()
      return false
    end)
  end
  vim.wait(500, function()
    return false
  end)
  t.check(
    "gs 'foobar' keeps only the handwritten one",
    table.concat(
      vim.tbl_map(function(i)
        return i.name .. "@" .. i.pos[1]
      end, p:items()),
      ", "
    ),
    "foobar@1"
  )
  p:close()
  -- a type used as a path qualifier is upright; a module qualifier is italic
  local function resolved(name)
    local n = name
    for _ = 1, 20 do
      local h = vim.api.nvim_get_hl(0, { name = n })
      if h.link then
        n = h.link
      elseif next(h) == nil and n:find("%.") then
        n = n:gsub("%.[^.]+$", "")
      else
        break
      end
    end
    return vim.api.nvim_get_hl(0, { name = n, link = false }).italic == true
  end
  local function italic_at(row, col)
    local info = vim.inspect_pos(0, row, col)
    for _, c in ipairs(info.treesitter) do
      if resolved(c.hl_group) then
        return true
      end
    end
    for _, tok in ipairs(info.semantic_tokens) do
      if resolved(tok.opts.hl_group) then
        return true
      end
    end
    return false
  end
  local usage = vim.fn.searchpos("Dongle::open()", "nw") -- the usage in use_it
  local m = vim.fn.searchpos("dongle::Error> { Dongle", "nw")
  local trow, tcol, mrow, mcol = usage[1] - 1, usage[2] - 1, m[1] - 1, m[2] - 1
  vim.wait(20000, function()
    return #vim.lsp.semantic_tokens.get_at_pos(0, trow, tcol) > 0
  end, 250)
  t.log(
    ("%s type as path qualifier (`Dongle::open`) upright: %s (want false)"):format(
      italic_at(trow, tcol) == false and "PASS" or "FAIL",
      tostring(italic_at(trow, tcol))
    )
  )
  t.log(
    ("%s module qualifier (`dongle::Error`) italic: %s (want true)"):format(
      italic_at(mrow, mcol) and "PASS" or "FAIL",
      tostring(italic_at(mrow, mcol))
    )
  )
  -- folds: rust-analyzer's ranges, normalised (util/foldranges.lua) so a
  -- fold hides its closing bracket and wrapped parameters keep `) -> R {`
  local function range(l)
    return vim.fn.foldclosed(l) .. ".." .. vim.fn.foldclosedend(l)
  end
  vim.fn.writefile({
    "use std::{",
    "    collections::HashMap,",
    "    fmt,",
    "};",
    "",
    "/// Doc comment line one",
    "/// Doc comment line two",
    "pub struct Core {",
    "    tracker: u8,",
    "    groups: Vec<u8>,",
    "}",
    "",
    "impl Core {",
    "    fn poll(&mut self) -> Result<u8, fmt::Error> {",
    "        Ok(self.tracker)",
    "    }",
    "",
    "    fn send(",
    "        &mut self,",
    "        channel: u8,",
    "        speed: u8,",
    "    ) -> Result<(), fmt::Error> {",
    "        let groups: Vec<State> = self",
    "            .groups",
    "            .iter()",
    "            .map(|g| State {",
    "                mac: *g,",
    "                online: true,",
    "            })",
    "            .collect();",
    "        if channel > 0 {",
    "            self.tracker = speed;",
    "        } else {",
    "            self.tracker = 0;",
    "        }",
    "        match channel {",
    "            0 => {",
    "                self.tracker = 1;",
    "            }",
    "            _ => {}",
    "        }",
    "        println!(",
    '            "{} {}",',
    "            channel,",
    "            speed",
    "        );",
    "        let arr = [",
    "            1,",
    "            2,",
    "        ];",
    "        Ok(())",
    "    }",
    "}",
    "",
    "struct State {",
    "    mac: u8,",
    "    online: bool,",
    "}",
    "",
    "fn cond(x: Option<u8>) -> u8 {",
    "    if x",
    "        .map(|v| v + 1)",
    "        .is_some()",
    "    {",
    "        return 1;",
    "    }",
    "    0",
    "}",
    "",
    "use std::fmt::Debug;",
    "use std::fmt::Display;",
  }, dir .. "/src/probe.rs")
  vim.cmd("edit " .. dir .. "/src/probe.rs")
  local FR = require("util.foldranges")
  vim.wait(30000, function()
    return FR.has(0)
  end, 100)
  vim.wait(500, function()
    return false
  end)
  t.check("probe folds come from rust-analyzer", FR.has(0), true)
  -- a run of `use` items is rust-analyzer's imports fold: folded on open,
  -- reading `use ...`
  t.check("a run of use items folds on open", range(70), "70..71")
  t.check("imports fold line", vim.fn.foldtextresult(70), "use ...")
  t.fold(27) -- `mac: *g,` in the struct literal inside the closure
  t.check(",d in a struct literal inside a closure folds it, closer included", range(27), "26..29")
  t.check("its fold line", vim.fn.foldtextresult(26), "            .map(|g| State { ... })")
  vim.cmd("normal! zR")
  t.fold(18)
  t.check(",d on a wrapped signature folds the parameters through `) -> R {`", range(18), "18..22")
  t.check("parameters fold line", vim.fn.foldtextresult(18), "    fn send( ... ) -> Result<(), fmt::Error> {")
  t.check("the body stays open under it", vim.fn.foldclosed(23), -1)
  t.fold(51) -- `Ok(())`, in the body and in nothing smaller
  t.check(",d in the body while the parameters are folded: the whole function", range(51), "18..52")
  t.check("whole-function fold line", vim.fn.foldtextresult(18), "    fn send( ... ) -> Result<(), fmt::Error> { ... }")
  vim.cmd("normal! zR")
  t.fold(51)
  t.check(",d in the body alone folds the body from `) -> R {`", range(51), "22..52")
  t.check("body fold line", vim.fn.foldtextresult(22), "    ) -> Result<(), fmt::Error> { ... }")
  t.check("the parameters stay open above it", vim.fn.foldclosed(18), -1)
  vim.cmd("normal! zR")
  t.fold(32)
  t.check("an if branch folds through its `} else {` line", range(32), "31..33")
  t.check("if-branch fold line", vim.fn.foldtextresult(31), "        if channel > 0 { ... } else {")
  t.check("the else body stays open under it", vim.fn.foldclosed(34), -1)
  t.fold(34)
  t.check(",d in the else while the if is folded: the whole chain", range(34), "31..35")
  t.check("whole-chain fold line", vim.fn.foldtextresult(31), "        if channel > 0 { ... } else { ... }")
  vim.cmd("normal! zR")
  t.fold(34)
  t.check(",d in the else alone folds the else branch", range(34), "33..35")
  t.check("else fold line", vim.fn.foldtextresult(33), "        } else { ... }")
  t.check("the if body stays open above it", vim.fn.foldclosed(32), -1)
  t.fold(32)
  t.check(",d in the if while the else is folded: the whole chain", range(32), "31..35")
  vim.cmd("normal! zR")
  t.fold(43)
  t.check("wrapped macro arguments fold through `);`", range(43), "42..46")
  t.check("macro fold line", vim.fn.foldtextresult(42), "        println!( ... );")
  vim.cmd("normal! zR")
  t.fold(62) -- inside a condition wrapped over three lines before its `{`
  t.check(",d in a wrapped condition folds the condition through its `{`", range(62), "61..64")
  t.check("condition fold line", vim.fn.foldtextresult(61), "    if x ... {")
  t.check("the body stays open under it", vim.fn.foldclosed(65), -1)
  t.fold(65)
  t.check(",d in the body while the condition is folded: the whole if", range(65), "61..66")
  t.check(
    "whole-if fold line shows the condition elided, then the body",
    vim.fn.foldtextresult(61),
    "    if x ... { ... }"
  )
  vim.cmd("normal! zR")
  t.fold(65)
  t.check(",d in the body alone folds the body from its `{`", range(65), "64..66")
  t.check("body fold line", vim.fn.foldtextresult(64), "    { ... }")
  t.check("the condition stays open above it", vim.fn.foldclosed(62), -1)

  vim.cmd("normal! zR")
end, { timeout = 90000, deadline = 150000 })
