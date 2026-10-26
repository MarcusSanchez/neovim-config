-- The completion menu (blink.cmp, LazyVim's default engine) styled like
-- the rest of the overlays — the gk hover, the ge float, the pickers and
-- the gd usages popup: a transparent body in a rounded blue border, the
-- cursor line for the selection, matched characters in blue, details
-- dimmed. Rows read like the usages popup's: the kind's icon, the label
-- with its detail, then the kind's name at the right. The documentation
-- beside the menu and the signature help get the same window. Groups in
-- catppuccin.lua.
local window = {
  border = "rounded",
  winhighlight = "Normal:CursorPopup,FloatBorder:CursorPopupBorder,CursorLine:BlinkCmpMenuSelection,Search:None",
  scrollbar = false,
}

return {
  "saghen/blink.cmp",
  opts = {
    completion = {
      menu = vim.tbl_extend("force", window, {
        draw = {
          columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "kind" } },
          components = {
            kind = { highlight = "BlinkCmpLabelDescription" }, -- the name dimmed, the icon keeps the kind's colour
          },
        },
      }),
      documentation = {
        window = vim.tbl_extend("force", window, {
          winhighlight = "Normal:CursorPopup,FloatBorder:CursorPopupBorder,EndOfBuffer:CursorPopup",
        }),
      },
    },
    signature = {
      window = vim.tbl_extend("force", window, {
        winhighlight = "Normal:CursorPopup,FloatBorder:CursorPopupBorder",
      }),
    },
  },
}
