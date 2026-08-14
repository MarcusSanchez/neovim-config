-- The dashboard is back (2026-08-13) — the oil/harpoon-era empty-buffer
-- launch is retired, and the isometric banner returns (sliced down from
-- the original MARCUS to just cus; the full six letters live in git
-- history at 56926ff~1).
return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      preset = {
        header = [[
      ___         ___         ___
     /  /\       /__/\       /  /\
    /  /:/       \  \:\     /  /:/_
   /  /:/         \  \:\   /  /:/ /\
  /  /:/  ___ ___  \  \:\ /  /:/ /::\
 /__/:/  /  //__/\  \__\:/__/:/ /:/\:\
 \  \:\ /  /:\  \:\ /  /:\  \:\/:/~/:/
  \  \:\  /:/ \  \:\  /:/ \  \::/ /:/
   \  \:\/:/   \  \:\/:/   \__\/ /:/
    \  \::/     \  \::/      /__/:/
     \__\/       \__\/       \__\/      ]],
      },
      sections = {
        { section = "header", padding = 3 },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      },
    },
  },
}
