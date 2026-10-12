-- Harpoon: pin the handful of files you keep bouncing between and jump to
-- them by slot. ,ha pins the current file, ,hl opens the list (edit it like
-- a buffer, :w or q to close), ,1 … ,9 jump to a slot. Lives alongside
-- bufferline tabs; a jump from an empty buffer replaces it rather than
-- adding a tab (lua/util/harpoon.lua). (Revived 2026-10-11 after being
-- benched since 2026-08-13.)
local keys = {
  {
    ",ha",
    function()
      require("harpoon"):list():add()
    end,
    desc = "Harpoon Add File",
  },
  {
    ",hl",
    function()
      local harpoon = require("harpoon")
      harpoon.ui:toggle_quick_menu(harpoon:list())
    end,
    desc = "Harpoon Quick Menu",
  },
}

for i = 1, 9 do
  table.insert(keys, {
    "," .. i,
    function()
      require("harpoon"):list():select(i)
    end,
    desc = "Harpoon File " .. i,
  })
end

return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    -- harpoon2's setup is a method, so lazy.nvim's default `opts` handling
    -- (dot-call) doesn't work here
    require("harpoon"):setup({ default = { select = require("util.harpoon").select } })
  end,
  keys = keys,
}
