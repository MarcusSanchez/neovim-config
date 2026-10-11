-- Name the custom prefixes so the which-key popup groups them instead of
-- showing a bare list. LazyVim declares opts_extend = { "spec" }, so these
-- entries are appended to its own spec rather than replacing it.
return {
  "folke/which-key.nvim",
  opts = {
    spec = {
      { ",", group = "custom", mode = "n" },
      { ",h", group = "harpoon", mode = "n" },
      { "<leader>h", group = "highlights", mode = "n" },
    },
  },
}
