-- JSX folds with the typescript server: an element folds through its
-- closing tag, a wrapped opening tag through its `/>` or `>`, a class
-- through its brace; each fold line shows the closer.
local lib = dofile(debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]*$") .. "/lib.lua")
lib.suite("vtsls", function(t)
  local FR = require("util.foldranges")
  local function fold(l) -- ,d on line l, everything else open
    vim.cmd("normal! zR")
    t.fold(l)
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
  t.check("a class folds through its brace", shape(9), "8..14 export class Store { ... }")
  fold(26)
  t.check("an element's content alone, from its >", shape(26), "25..27 > ... </header>")
  vim.cmd("normal! 19G")
  FR.toggle()
  t.check(
    "then its attributes: the whole element through the closing tag",
    shape(19),
    "19..27 <header ... > ... </header>"
  )
  fold(19)
  t.check("a wrapped opening tag folds its attributes through >", shape(19), "19..25 <header ... >")
  fold(21)
  t.check("a className call folds on its own", shape(21), "20..23 className={cn( ... )}")
  fold(29)
  t.check("a self-closing tag folds through />", shape(29), "28..31 <Hero ... />")
  fold(33)
  t.check("a self-closing tag the server skips (treesitter knows it)", shape(33), "32..35 <script ... />")
  fold(41)
  t.check("an element with wrapped attributes: its content alone, from the >", shape(41), "40..42 > ... </a>")
  t.check("the attributes stay open above it", vim.fn.foldclosed(38), -1)
  vim.cmd("normal! 38G")
  FR.toggle()
  t.check("folding the attributes over the folded content: the whole element", shape(38), "37..42 <a ... > ... </a>")
  fold(38)
  t.check("its attribute list on its own", shape(38), "37..40 <a ... >")
  t.check("the content stays open under it", vim.fn.foldclosed(41), -1)
  vim.cmd("normal! 41G")
  FR.toggle()
  t.check("folding the content over the folded attributes: the whole element", shape(41), "37..42 <a ... > ... </a>")
  fold(46)
  t.check("a nested element", shape(46), "45..47 <li key={item}> ... </li>")
  fold(44)
  t.check("a map callback", shape(44), "44..48 {items.map((item) => ( ... ))}")
  fold(50)
  t.check("a conditional", shape(50), "50..54 {open && ( ... )}")
  fold(51)
  t.check("the element inside it", shape(51), "51..53 <aside> ... </aside>")
  fold(56)
  t.check("a fragment folds through </>", shape(56), "55..58 <> ... </>")
  fold(65)
  t.check("an arrow component's element", shape(65), '64..66 <div className="card"> ... </div>')
  fold(63)
  t.check("the arrow component", shape(63), "63..67 const Card = ({ title }: { title: string }) => ( ... );")
  fold(18)
  t.check("the root element", shape(18), '18..59 <main className="flex flex-col"> ... </main>')
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
  t.check(
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
  t.check("no fold-line chunk falls back to Folded", folded_fallbacks(), "")
  vim.cmd("normal! zR")
  vim.cmd("normal! 41G")
  FR.toggle()
  vim.wo.foldtext = "v:lua.__probe()"
  vim.fn.foldtextresult(37)
  vim.wo.foldtext = ft
  t.check("the <a> fold line has no Folded fallback either", folded_fallbacks(), "")
  t.log("OK")
end, { timeout = 90000 })
