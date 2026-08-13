-- Harpoon bindings: ,ha adds, ,hl opens the quick menu, and bare ,1–,9
-- jump straight to that slot.
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
    require("harpoon"):setup()
  end,
  keys = keys,
}
