-- JSX folds with the typescript server: an element folds through its
-- closing tag, a wrapped opening tag through its `/>` or `>`, a class
-- through its brace; each fold line shows the closer.
local dir = vim.fn.expand("%:p:h")
local logf = io.open(dir .. "/result.log", "w")
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
end, 120000)
vim.schedule(function()
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
    local FR = require("util.foldranges")
    vim.wait(90000, function()
      return FR.has(0)
    end, 200)
    vim.wait(800, function()
      return false
    end)
    check("folds come from the typescript server", FR.has(0), true)
    local function fold(l)
      vim.cmd("normal! zR")
      vim.cmd(("normal! %dG"):format(l))
      FR.toggle()
    end
    local function shape(l)
      local s = vim.fn.foldclosed(l)
      return s
        .. ".."
        .. vim.fn.foldclosedend(l)
        .. " "
        .. (s > 0 and vim.fn.foldtextresult(s):gsub("^%s+", "") or "(open)")
    end
    fold(9)
    check("a class folds through its brace", shape(9), "8..14 export class Store { ... }")
    fold(26)
    check("an element folds through its closing tag", shape(26), "19..27 <header ... > ... </header>")
    fold(19)
    check("a wrapped opening tag folds its attributes through >", shape(19), "19..25 <header ... >")
    fold(21)
    check("a className call folds on its own", shape(21), "20..23 className={cn( ... )}")
    fold(29)
    check("a self-closing tag folds through />", shape(29), "28..31 <Hero ... />")
    fold(33)
    check("a self-closing tag the server skips (treesitter knows it)", shape(33), "32..35 <script ... />")
    fold(41)
    check("an element with wrapped attributes, from its text", shape(41), "37..42 <a ... > ... </a>")
    fold(38)
    check("its attribute list on its own", shape(38), "37..40 <a ... >")
    fold(46)
    check("a nested element", shape(46), "45..47 <li key={item}> ... </li>")
    fold(44)
    check("a map callback", shape(44), "44..48 {items.map((item) => ( ... ))}")
    fold(50)
    check("a conditional", shape(50), "50..54 {open && ( ... )}")
    fold(51)
    check("the element inside it", shape(51), "51..53 <aside> ... </aside>")
    fold(56)
    check("a fragment folds through </>", shape(56), "55..58 <> ... </>")
    fold(65)
    check("an arrow component's element", shape(65), '64..66 <div className="card"> ... </div>')
    fold(63)
    check("the arrow component", shape(63), "63..67 const Card = ({ title }: { title: string }) => ( ... );")
    fold(18)
    check("the root element", shape(18), '18..59 <main className="flex flex-col"> ... </main>')
    -- the closing tag on the fold line is dim, like a `}` the fold hides behind
    _G.__probe = function()
      local c = require("util.foldtext").text()
      _G.__chunks = c
      return c
    end
    local ft = vim.wo.foldtext
    vim.wo.foldtext = "v:lua.__probe()"
    vim.fn.foldtextresult(18)
    vim.wo.foldtext = ft
    check(
      "closing tag keeps its colours on the fold line",
      _G.__chunks[#_G.__chunks][1] .. "=" .. _G.__chunks[#_G.__chunks][2],
      ">=@tag.delimiter.tsx"
    )
    -- every visible chunk has a colour of its own: attribute names and tag
    -- names must not fall back to Folded (helper captures carry no colour)
    local function folded_fallbacks()
      local blue = {}
      for _, c in ipairs(_G.__chunks) do
        local h = vim.api.nvim_get_hl(0, { name = c[2], link = false })
        if not c[1]:match("^%s*$") and h.fg == nil then
          blue[#blue + 1] = c[1] .. "=" .. c[2]
        end
      end
      return table.concat(blue, " ")
    end
    check("no fold-line chunk falls back to Folded", folded_fallbacks(), "")
    vim.cmd("normal! zR")
    vim.cmd("normal! 41G")
    FR.toggle()
    vim.wo.foldtext = "v:lua.__probe()"
    vim.fn.foldtextresult(37)
    vim.wo.foldtext = ft
    check("the <a> fold line has no Folded fallback either", folded_fallbacks(), "")
    log("OK")
  end)
  log(ok and "DONE" or ("ERROR: " .. tostring(err)))
  vim.cmd("qall!")
end)
