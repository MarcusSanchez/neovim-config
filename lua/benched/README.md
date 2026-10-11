# Benched plugin specs

Experiments that were tried and shelved, kept as real lazy.nvim specs so
they're one `mv` away from coming back (oil and harpoon came back this way
on 2026-10-11 and now live in lua/plugins/). `lua/benched/` is not imported by
lazy.nvim — to revive one, move its file into `lua/plugins/` and follow the
notes at the top of the file.

- `neo-tree.lua` — neo-tree as the sidebar, benched 2026-10-11 after a day:
  same shape as the snacks explorer minus its filter input. The helper
  `lua/util/explorer.lua` still has its backend.
