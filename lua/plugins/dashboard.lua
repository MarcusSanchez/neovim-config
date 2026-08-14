-- The dashboard banner: the Costco one-liner (the cus experiments — the
-- isometric slice, then larry3d — live in git history if the mood returns;
-- keep any future ascii header right-stripped, trailing whitespace shifts
-- snacks' centering).
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
