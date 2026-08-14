-- The dashboard banner: cus in larry3d (swapped from the isometric slice
-- 2026-08-13; every line is right-stripped — trailing whitespace widens the
-- block and shifts snacks' centering).
return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      preset = {
        header = [==[
  ___   __  __    ____
 /'___\/\ \/\ \  /',__\
/\ \__/\ \ \_\ \/\__, `\
\ \____\\ \____/\/\____/
 \/____/ \/___/  \/___/]==],
      },
      sections = {
        { section = "header", padding = 3 },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      },
    },
  },
}
