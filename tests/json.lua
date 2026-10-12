-- fold shapes: JSON with the json server (tests/fixtures/json).
local lib = dofile(debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]*$") .. "/lib.lua")
lib.suite("jsonls", function(t)
  t.shape(2, "1..18", "{ ... }")
  t.shape(4, "3..9", '  "nested": { ... },')
  t.shape(6, "5..8", '    "b": [ ... ]')
  t.shape(10, "10..17", '  "list": [ ... ]')
  t.shape(12, "11..13", "    { ... },")
end)
