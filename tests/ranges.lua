-- util.foldranges.normalize: the folding ranges rust-analyzer, gopls and
-- vtsls answered for three probe files (captured 2026-10-11), and the
-- IntelliJ-shaped folds they must become: a fold hides its closing bracket
-- (`}`, `});`, `}, log)`), wrapped parameters keep their `) -> R {` and the
-- body folds with the whole function, `} else {` stays visible with the
-- else branch its own fold. No server needed.
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
end, 30000)
local N = require("util.foldranges").normalize
local function shapes(ranges, lines)
  local out = {}
  for _, r in ipairs(N(ranges, lines)) do
    out[#out + 1] = (r.s + 1) .. ".." .. (r.e + 1)
  end
  return table.concat(out, " ")
end
local ok, err = pcall(function()
  local rust = {
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
  }
  local go = {
    "package main",
    "",
    "import (",
    '\t"context"',
    '\t"fmt"',
    ")",
    "",
    "// Comment line one",
    "// Comment line two",
    "type Config struct {",
    "\tDriver string",
    "\tName   string",
    "}",
    "",
    "func h(",
    "\ta int,",
    "\tb int,",
    ") int {",
    "\treturn a + b",
    "}",
    "",
    "func run(ctx context.Context) error {",
    "\tsender, err := mail.New(mail.Config{",
    '\t\tDriver: "x",',
    '\t\tName:   "y",',
    "\t}, log)",
    "\tif err != nil {",
    "\t\treturn err",
    "\t} else {",
    "\t\tfmt.Println(sender)",
    "\t}",
    "\tsrv := server.New(",
    "\t\tdb,",
    "\t\tenc,",
    "\t)",
    "\tx := g(1, func() int {",
    "\t\treturn 1",
    "\t})",
    "\tvar q = `",
    "select 1",
    "`",
    "\tarr := []string{",
    '\t\t"a",',
    '\t\t"b",',
    "\t}",
    "\treturn nil",
    "}",
  }
  local ts = {
    "import {",
    "  a,",
    "  b,",
    '} from "./x";',
    "",
    "/**",
    " * Doc comment",
    " */",
    "export function send(",
    "  channel: number,",
    "  speed: number,",
    "): Promise<void> {",
    "  const groups = items",
    "    .filter((g) => g.online)",
    "    .map((g) => ({",
    "      mac: g.mac,",
    "      online: true,",
    "    }));",
    "  if (channel > 0) {",
    "    speed = 1;",
    "  } else {",
    "    speed = 0;",
    "  }",
    "  const rows = [",
    '    { id: 1, name: "a" },',
    "    {",
    "      id: 2,",
    '      name: "b",',
    "    },",
    "  ];",
    "  fetch(url).then((res) => {",
    "    return res;",
    "  }).catch((e) => {",
    "    throw e;",
    "  });",
    "  call(",
    "    channel,",
    "    speed,",
    "  );",
    "}",
    "",
    "class Core {",
    "  run(): void {",
    "    return;",
    "  }",
    "}",
  }
  check(
    "rust-analyzer ranges normalised",
    shapes({
      { startLine = 0, endLine = 2 },
      { startLine = 5, endLine = 6, kind = "comment" },
      { startLine = 7, endLine = 10 },
      { startLine = 12, endLine = 52 },
      { startLine = 13, endLine = 15 },
      { startLine = 17, endLine = 51 },
      { startLine = 17, endLine = 20 },
      { startLine = 21, endLine = 51 },
      { startLine = 22, endLine = 29 },
      { startLine = 25, endLine = 28 },
      { startLine = 25, endLine = 27 },
      { startLine = 30, endLine = 34 },
      { startLine = 30, endLine = 31 },
      { startLine = 32, endLine = 34 },
      { startLine = 35, endLine = 40 },
      { startLine = 35, endLine = 40 },
      { startLine = 36, endLine = 38 },
      { startLine = 41, endLine = 45 },
      { startLine = 41, endLine = 44 },
      { startLine = 46, endLine = 49 },
      { startLine = 46, endLine = 48 },
      { startLine = 54, endLine = 57 },
    }, rust),
    table.concat({
      "1..4",
      "6..7",
      "8..11",
      "13..53",
      "14..16",
      "18..52",
      "18..22",
      "22..52",
      "23..30",
      "26..29",
      "31..35",
      "31..33",
      "33..35",
      "36..41",
      "37..39",
      "42..46",
      "47..50",
      "55..58",
    }, " ")
  )
  check(
    "gopls ranges normalised",
    shapes({
      { startLine = 2, endLine = 4, kind = "imports" },
      { startLine = 7, endLine = 8, kind = "comment" },
      { startLine = 9, endLine = 11 },
      { startLine = 14, endLine = 16 },
      { startLine = 17, endLine = 18 },
      { startLine = 21, endLine = 45 },
      { startLine = 22, endLine = 24 },
      { startLine = 22, endLine = 24 },
      { startLine = 26, endLine = 27 },
      { startLine = 28, endLine = 29 },
      { startLine = 31, endLine = 33 },
      { startLine = 35, endLine = 36 },
      { startLine = 35, endLine = 36 },
      { startLine = 38, endLine = 40 },
      { startLine = 41, endLine = 43 },
    }, go),
    table.concat({
      "3..6",
      "8..9",
      "10..13",
      "15..20",
      "15..18",
      "18..20",
      "22..47",
      "23..26",
      "27..31",
      "27..29",
      "29..31",
      "32..35",
      "36..38",
      "39..41",
      "42..45",
    }, " ")
  )
  check(
    "vtsls ranges normalised",
    shapes({
      { startLine = 0, endLine = 2 },
      { startLine = 5, endLine = 7, kind = "comment" },
      { startLine = 8, endLine = 38 },
      { startLine = 14, endLine = 16 },
      { startLine = 14, endLine = 16 },
      { startLine = 14, endLine = 16 },
      { startLine = 18, endLine = 19 },
      { startLine = 20, endLine = 21 },
      { startLine = 23, endLine = 28 },
      { startLine = 24, endLine = 24 },
      { startLine = 25, endLine = 27 },
      { startLine = 30, endLine = 31 },
      { startLine = 30, endLine = 31 },
      { startLine = 32, endLine = 33 },
      { startLine = 32, endLine = 33 },
      { startLine = 35, endLine = 37 },
      { startLine = 41, endLine = 44 },
      { startLine = 42, endLine = 43 },
    }, ts),
    table.concat({
      "1..4",
      "6..8",
      "9..40",
      "15..18",
      "19..23",
      "19..21",
      "21..23",
      "24..30",
      "26..29",
      "31..35",
      "31..33",
      "33..35",
      "36..39",
      "42..46",
      "43..45",
    }, " ")
  )
  -- vtsls on a TSX file (captured 2026-10-12): an element's range stops
  -- before its closing tag and grows onto it; a wrapped opening tag's
  -- attribute-only range grows up to the tag and onto its `/>` or `>`
  local tsx = {
    'import { cn } from "./cn";',
    "",
    "type Props = {",
    "  items: string[];",
    "  open: boolean;",
    "};",
    "",
    "export class Store {",
    "  private items: string[] = [];",
    "",
    "  add(item: string): void {",
    "    this.items.push(item);",
    "  }",
    "}",
    "",
    "export default function Page({ items, open }: Props) {",
    "  return (",
    '    <main className="flex flex-col">',
    "      <header",
    "        className={cn(",
    '          "sticky top-0",',
    '          open && "shadow"',
    "        )}",
    '        role="banner"',
    "      >",
    "        <h1>Title</h1>",
    "      </header>",
    "      <Hero",
    '        title="Hi"',
    '        subtitle="There"',
    "      />",
    "      <ul>",
    "        {items.map((item) => (",
    "          <li key={item}>",
    "            {item}",
    "          </li>",
    "        ))}",
    "      </ul>",
    "      {open && (",
    "        <aside>",
    "          <p>Open</p>",
    "        </aside>",
    "      )}",
    "      <>",
    "        <span>a</span>",
    "        <span>b</span>",
    "      </>",
    "    </main>",
    "  );",
    "}",
    "",
    "const Card = ({ title }: { title: string }) => (",
    '  <div className="card">',
    "    <h2>{title}</h2>",
    "  </div>",
    ");",
  }
  check(
    "vtsls JSX ranges normalised",
    shapes({
      { startLine = 2, endLine = 4 },
      { startLine = 7, endLine = 12 },
      { startLine = 8, endLine = 8 },
      { startLine = 10, endLine = 11 },
      { startLine = 15, endLine = 15 },
      { startLine = 15, endLine = 48 },
      { startLine = 16, endLine = 47 },
      { startLine = 17, endLine = 46 },
      { startLine = 17, endLine = 17 },
      { startLine = 18, endLine = 25 },
      { startLine = 19, endLine = 23 },
      { startLine = 19, endLine = 21 },
      { startLine = 25, endLine = 25 },
      { startLine = 28, endLine = 29 },
      { startLine = 31, endLine = 36 },
      { startLine = 32, endLine = 35 },
      { startLine = 32, endLine = 35 },
      { startLine = 33, endLine = 34 },
      { startLine = 33, endLine = 33 },
      { startLine = 38, endLine = 41 },
      { startLine = 39, endLine = 40 },
      { startLine = 40, endLine = 40 },
      { startLine = 43, endLine = 45 },
      { startLine = 44, endLine = 44 },
      { startLine = 45, endLine = 45 },
      { startLine = 51, endLine = 51 },
      { startLine = 51, endLine = 51 },
      { startLine = 51, endLine = 54 },
      { startLine = 52, endLine = 53 },
      { startLine = 52, endLine = 52 },
      { startLine = 53, endLine = 53 },
    }, tsx),
    "3..6 8..14 11..13 16..50 17..49 18..48 19..27 19..25 20..23 25..27 28..31 32..38 33..37 34..36 39..43 40..42 44..47 52..56 53..55"
  )
  -- shared rows: resolve() hands each one to its owner — the range ending
  -- there unless the owners table says the one starting there — so Vim
  -- never sees two folds on a line
  local R = require("util.foldranges").resolve
  local function resolved(ranges, owners)
    local out = {}
    for _, r in ipairs(R(ranges, owners)) do
      out[#out + 1] = (r.s + 1) .. ".." .. (r.e + 1)
    end
    return table.concat(out, " ")
  end
  local chain = {
    { s = 14, e = 19 },
    { s = 14, e = 17 },
    { s = 17, e = 19 },
    { s = 26, e = 30 },
    { s = 26, e = 28 },
    { s = 28, e = 30 },
  }
  check(
    "by default the ending range keeps the shared row",
    resolved(chain, {}),
    "15..20 15..18 19..20 27..31 27..29 30..31"
  )
  check(
    "an owner named for the row hands it to the range starting there",
    resolved(chain, { [17] = "start", [28] = "start" }),
    "15..20 15..17 18..20 27..31 27..28 29..31"
  )
  check(
    "a row no range shares is untouched by owners",
    resolved(chain, { [15] = "start" }),
    "15..20 15..18 19..20 27..31 27..29 30..31"
  )
  -- fold levels: a "<" only where Vim needs one (next row as deep, or itself
  -- marked), never where the level drops, since "<" drags unmarked folds
  local L = require("util.foldranges").levels
  local function marks(levels, rows)
    local out = {}
    for _, row in ipairs(rows) do
      local l = levels[row - 1]
      out[#out + 1] = row .. "=" .. (l and ((l[2] or "") .. l[1]) or "0")
    end
    return table.concat(out, " ")
  end
  local lv = L(R(
    N({
      { startLine = 12, endLine = 52 },
      { startLine = 17, endLine = 51 },
      { startLine = 17, endLine = 20 },
      { startLine = 21, endLine = 51 },
      { startLine = 22, endLine = 29 },
      { startLine = 25, endLine = 28 },
      { startLine = 25, endLine = 27 },
      { startLine = 30, endLine = 34 },
      { startLine = 30, endLine = 31 },
      { startLine = 32, endLine = 34 },
    }, rust),
    {}
  ))
  check("parameters' end marked: body and let start deeper right after", marks(lv, { 22, 23 }), "22=<3 23=>4")
  check("map literal's end marked because the let's end is marked", marks(lv, { 29, 30, 31 }), "29=<5 30=<4 31=>5")
  check("fn and body end unmarked: the level drops to the impl", marks(lv, { 51, 52, 53, 54 }), "51=3 52=3 53=1 54=0")
  -- a comment range keeps its kind
  local kinds = {}
  for _, r in
    ipairs(N({
      { startLine = 2, endLine = 4, kind = "imports" },
      { startLine = 7, endLine = 8, kind = "comment" },
      { startLine = 9, endLine = 11 },
      { startLine = 14, endLine = 16 },
      { startLine = 17, endLine = 18 },
      { startLine = 21, endLine = 45 },
      { startLine = 22, endLine = 24 },
      { startLine = 22, endLine = 24 },
      { startLine = 26, endLine = 27 },
      { startLine = 28, endLine = 29 },
      { startLine = 31, endLine = 33 },
      { startLine = 35, endLine = 36 },
      { startLine = 35, endLine = 36 },
      { startLine = 38, endLine = 40 },
      { startLine = 41, endLine = 43 },
    }, go))
  do
    if r.kind then
      kinds[#kinds + 1] = (r.s + 1) .. "=" .. r.kind
    end
  end
  check("kinds survive", table.concat(kinds, " "), "3=imports 8=comment")
  -- zls (captured 2026-10-12): if/else chains nested in both branches of
  -- an if/else. The inner else's `}` ends the else and its chain at once:
  -- the "<" there must name the chain's level, or Vim carries the chain on
  -- to the outer `} else {`, which is marked itself
  local zig = {
    "fn insertNode(self: *Tree, node: *Node, value: i32) !*Node {",
    "    if (value < node.value) {",
    "        if (node.left) |left| {",
    "            return self.insertNode(left, value);",
    "        } else {",
    "            node.left = try Node.init(self.allocator, value, node);",
    "            return node.left.?;",
    "        }",
    "    } else {",
    "        if (node.right) |right| {",
    "            return self.insertNode(right, value);",
    "        } else {",
    "            node.right = try Node.init(self.allocator, value, node);",
    "            return node.right.?;",
    "        }",
    "    }",
    "}",
  }
  local zls = {
    { startLine = 2, endLine = 3 },
    { startLine = 4, endLine = 6 },
    { startLine = 1, endLine = 7 },
    { startLine = 9, endLine = 10 },
    { startLine = 11, endLine = 13 },
    { startLine = 8, endLine = 14 },
    { startLine = 0, endLine = 15 },
  }
  check("zls ranges normalised", shapes(zls, zig), "1..17 2..16 2..9 3..8 3..5 5..8 9..16 10..15 10..12 12..15")
  lv = L(R(N(zls, zig), {}))
  check("a `}` ending an else and its chain is marked at the chain's level", marks(lv, { 8 }), "8=<4")
  check("the outer `} else {` ends the if branch there", marks(lv, { 9, 10 }), "9=<3 10=>5")
  -- a block that already ends on its closer is left alone even when the
  -- next line is the parent's closer
  local nested = { "let x = [", "    || {", "        a", "    }", "];" }
  check(
    "a closed block doesn't swallow its parent's closer",
    shapes({ { startLine = 1, endLine = 3 }, { startLine = 0, endLine = 3 } }, nested),
    "1..5 2..4"
  )
  -- a wrapped call inside wrapped arguments: both close
  local calls = { "foo(", "    bar(", "        1,", "    ),", ")" }
  check(
    "nested wrapped calls both close",
    shapes({ { startLine = 0, endLine = 3 }, { startLine = 1, endLine = 2 } }, calls),
    "1..5 2..4"
  )
end)
log(ok and "DONE" or ("ERROR: " .. tostring(err)))
vim.cmd("qall!")
