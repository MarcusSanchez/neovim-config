-- The dashboard is back (2026-08-13) — the oil/harpoon-era empty-buffer
-- launch is retired. snacks.lua no longer carries an enabled=false override.
return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      preset = {
        header = "Welcome to Costco. I love you.",
      },
      sections = {
        { section = "header", padding = 3 },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      },
    },
  },
}
