-- fold shapes: TOML with treesitter (tests/fixtures/toml): taplo answers with no ranges, so treesitter's folds stay.
local lib = dofile(debug.getinfo(1, "S").source:sub(2):match("^(.*)/[^/]*$") .. "/lib.lua")
lib.suite("taplo", function(t)
  t.shape(6, "5..11", "[server] ...")
  t.shape(8, "7..10", "ports = [ ... ]")
  t.shape(13, "12..14", "[server.tls] ...")
  t.shape(16, "15..17", "[[items]] ...")
end, { treesitter = true })
