-- util.foldranges.normalize: the folding ranges rust-analyzer, gopls and
-- vtsls answered for three probe files (captured 2026-10-11), and the
-- IntelliJ-shaped folds they must become: a fold hides its closing bracket
-- (`}`, `});`, `}, log)`), wrapped parameters keep their `) -> R {` and the
-- body folds with the whole function, `} else {` stays visible with the
-- else branch its own fold. No server needed.
local logf = io.open(vim.fn.getcwd() .. "/result.log", "w")
local function log(s) logf:write(s, "\n"); logf:flush() end
local function check(name, got, want) log(("%s %s: %s (want %s)"):format(got == want and "PASS" or "FAIL", name, tostring(got), tostring(want))) end
vim.defer_fn(function() log("TIMEOUT"); vim.cmd("qall!") end, 30000)
local N = require("util.foldranges").normalize
local function shapes(ranges, lines)
  local out = {}
  for _, r in ipairs(N(ranges, lines)) do out[#out + 1] = (r.startLine + 1) .. ".." .. (r.endLine + 1) end
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
  "            \"{} {}\",",
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
  "\t\"context\"",
  "\t\"fmt\"",
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
  "\t\tDriver: \"x\",",
  "\t\tName:   \"y\",",
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
  "\t\t\"a\",",
  "\t\t\"b\",",
  "\t}",
  "\treturn nil",
  "}",
}
  local ts = {
  "import {",
  "  a,",
  "  b,",
  "} from \"./x\";",
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
  "    { id: 1, name: \"a\" },",
  "    {",
  "      id: 2,",
  "      name: \"b\",",
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
  check("rust-analyzer ranges normalised", shapes({ { startLine = 0, endLine = 2 }, { startLine = 5, endLine = 6, kind = "comment" }, { startLine = 7, endLine = 10 }, { startLine = 12, endLine = 52 }, { startLine = 13, endLine = 15 }, { startLine = 17, endLine = 51 }, { startLine = 17, endLine = 20 }, { startLine = 21, endLine = 51 }, { startLine = 22, endLine = 29 }, { startLine = 25, endLine = 28 }, { startLine = 25, endLine = 27 }, { startLine = 30, endLine = 34 }, { startLine = 30, endLine = 31 }, { startLine = 32, endLine = 34 }, { startLine = 35, endLine = 40 }, { startLine = 35, endLine = 40 }, { startLine = 36, endLine = 38 }, { startLine = 41, endLine = 45 }, { startLine = 41, endLine = 44 }, { startLine = 46, endLine = 49 }, { startLine = 46, endLine = 48 }, { startLine = 54, endLine = 57 } }, rust), table.concat({ "1..4", "6..7", "8..11", "13..53", "14..16", "18..52", "18..22", "23..30", "26..29", "31..35", "31..32", "33..35", "36..41", "37..39", "42..46", "47..50", "55..58" }, " "))
  check("gopls ranges normalised", shapes({ { startLine = 2, endLine = 4, kind = "imports" }, { startLine = 7, endLine = 8, kind = "comment" }, { startLine = 9, endLine = 11 }, { startLine = 14, endLine = 16 }, { startLine = 17, endLine = 18 }, { startLine = 21, endLine = 45 }, { startLine = 22, endLine = 24 }, { startLine = 22, endLine = 24 }, { startLine = 26, endLine = 27 }, { startLine = 28, endLine = 29 }, { startLine = 31, endLine = 33 }, { startLine = 35, endLine = 36 }, { startLine = 35, endLine = 36 }, { startLine = 38, endLine = 40 }, { startLine = 41, endLine = 43 } }, go), table.concat({ "3..6", "8..9", "10..13", "15..20", "15..18", "22..47", "23..26", "27..28", "29..31", "32..35", "36..38", "39..41", "42..45" }, " "))
  check("vtsls ranges normalised", shapes({ { startLine = 0, endLine = 2 }, { startLine = 5, endLine = 7, kind = "comment" }, { startLine = 8, endLine = 38 }, { startLine = 14, endLine = 16 }, { startLine = 14, endLine = 16 }, { startLine = 14, endLine = 16 }, { startLine = 18, endLine = 19 }, { startLine = 20, endLine = 21 }, { startLine = 23, endLine = 28 }, { startLine = 24, endLine = 24 }, { startLine = 25, endLine = 27 }, { startLine = 30, endLine = 31 }, { startLine = 30, endLine = 31 }, { startLine = 32, endLine = 33 }, { startLine = 32, endLine = 33 }, { startLine = 35, endLine = 37 }, { startLine = 41, endLine = 44 }, { startLine = 42, endLine = 43 } }, ts), table.concat({ "1..4", "6..8", "9..40", "15..18", "19..20", "21..23", "24..30", "26..29", "31..32", "33..35", "36..39", "42..46", "43..45" }, " "))
  -- idempotent: normalising the result changes nothing
  local once = N({ { startLine = 2, endLine = 4, kind = "imports" }, { startLine = 7, endLine = 8, kind = "comment" }, { startLine = 9, endLine = 11 }, { startLine = 14, endLine = 16 }, { startLine = 17, endLine = 18 }, { startLine = 21, endLine = 45 }, { startLine = 22, endLine = 24 }, { startLine = 22, endLine = 24 }, { startLine = 26, endLine = 27 }, { startLine = 28, endLine = 29 }, { startLine = 31, endLine = 33 }, { startLine = 35, endLine = 36 }, { startLine = 35, endLine = 36 }, { startLine = 38, endLine = 40 }, { startLine = 41, endLine = 43 } }, go)
  check("normalising twice is the same", shapes(once, go), shapes({ { startLine = 2, endLine = 4, kind = "imports" }, { startLine = 7, endLine = 8, kind = "comment" }, { startLine = 9, endLine = 11 }, { startLine = 14, endLine = 16 }, { startLine = 17, endLine = 18 }, { startLine = 21, endLine = 45 }, { startLine = 22, endLine = 24 }, { startLine = 22, endLine = 24 }, { startLine = 26, endLine = 27 }, { startLine = 28, endLine = 29 }, { startLine = 31, endLine = 33 }, { startLine = 35, endLine = 36 }, { startLine = 35, endLine = 36 }, { startLine = 38, endLine = 40 }, { startLine = 41, endLine = 43 } }, go))
  -- a comment range keeps its kind
  local kinds = {}
  for _, r in ipairs(N({ { startLine = 2, endLine = 4, kind = "imports" }, { startLine = 7, endLine = 8, kind = "comment" }, { startLine = 9, endLine = 11 }, { startLine = 14, endLine = 16 }, { startLine = 17, endLine = 18 }, { startLine = 21, endLine = 45 }, { startLine = 22, endLine = 24 }, { startLine = 22, endLine = 24 }, { startLine = 26, endLine = 27 }, { startLine = 28, endLine = 29 }, { startLine = 31, endLine = 33 }, { startLine = 35, endLine = 36 }, { startLine = 35, endLine = 36 }, { startLine = 38, endLine = 40 }, { startLine = 41, endLine = 43 } }, go)) do if r.kind then kinds[#kinds + 1] = (r.startLine + 1) .. "=" .. r.kind end end
  check("kinds survive", table.concat(kinds, " "), "3=imports 8=comment")
  -- a block that already ends on its closer is left alone even when the
  -- next line is the parent's closer
  local nested = { "let x = [", "    || {", "        a", "    }", "];" }
  check("a closed block doesn't swallow its parent's closer", shapes({ { startLine = 1, endLine = 3 }, { startLine = 0, endLine = 3 } }, nested), "1..5 2..4")
  -- a wrapped call inside wrapped arguments: both close
  local calls = { "foo(", "    bar(", "        1,", "    ),", ")" }
  check("nested wrapped calls both close", shapes({ { startLine = 0, endLine = 3 }, { startLine = 1, endLine = 2 } }, calls), "1..5 2..4")
end)
log(ok and "DONE" or ("ERROR: " .. tostring(err)))
vim.cmd("qall!")
