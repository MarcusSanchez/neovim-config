-- fold shapes: Markdown with treesitter (tests/fixtures/md): sections fold under their heading, code fences through their closing fence.
local lib = dofile(debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]*$") .. "/lib.lua")
lib.suite("marksman", function(t)
  t.shape(7, "6..18", "## Section one ...")
  t.shape(12, "11..14", "```lua ... ```")
  t.shape(17, "16..18", "### Subsection ...")
  t.shape(21, "20..22", "## Section two ...")
  t.shape(3, "1..22", "# Title ...")
end, { treesitter = true })
