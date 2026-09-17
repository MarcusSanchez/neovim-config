return {
  "folke/noice.nvim",
  opts = {
    lsp = {
      hover = { silent = true },
    },
    views = {
      -- gk hover: styled like the snacks picker popups (rounded blue border on
      -- the transparent background) instead of a borderless opaque slab. The
      -- groups are defined in catppuccin.lua.
      hover = {
        border = { style = "rounded", padding = { 0, 1 } },
        -- the border takes the row above the body: row 2 keeps the border
        -- off the cursor line
        position = { row = 2, col = 0 },
        win_options = {
          winhighlight = { Normal = "CursorPopup", FloatBorder = "CursorPopupBorder" },
        },
      },
    },
  },
}
