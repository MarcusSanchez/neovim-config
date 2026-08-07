-- Stripped-down statusline: no icons, no powerline separators, just
-- mode / branch / filename on the left and diagnostics / position on the
-- right. opts is a function so it fully replaces LazyVim's fancy default
-- lualine config instead of merging with it.
return {
  "nvim-lualine/lualine.nvim",
  opts = function()
    return {
      options = {
        icons_enabled = false,
        theme = "auto",
        component_separators = "",
        section_separators = "",
        globalstatus = true,
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "diagnostics" },
        lualine_y = {},
        lualine_z = { "location" },
      },
    }
  end,
}
