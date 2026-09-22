return {
  "folke/noice.nvim",
  init = function()
    -- noice maps K in its markdown (hover) buffers to "open the link under
    -- the cursor, else the builtin K" — and the builtin K is keywordprg, i.e.
    -- a man page. Wrap the mapper so K inside the hover scrolls half a page
    -- down like everywhere else in this config, and gd follows the
    -- "Go to [Type](file://...)" links (lua/util/popup.lua); gx still opens
    -- links in the browser.
    vim.api.nvim_create_autocmd("User", {
      pattern = "LazyLoad",
      callback = function(ev)
        if ev.data ~= "noice.nvim" then
          return
        end
        local markdown = require("noice.text.markdown")
        local keys = markdown.keys
        markdown.keys = function(buf)
          keys(buf)
          vim.keymap.set("n", "K", "<C-D>", { buffer = buf, silent = true, desc = "Scroll Half Page Down" })
          vim.keymap.set("n", "gd", function()
            require("util.popup").follow_link()
          end, { buffer = buf, silent = true, desc = "Goto Linked Definition" })
        end
        return true -- one-shot
      end,
    })
  end,
  opts = {
    lsp = {
      hover = { silent = true },
    },
    views = {
      -- gk hover: styled like the snacks picker popups (rounded blue border on
      -- the transparent background) instead of a borderless opaque slab. The
      -- groups are defined in catppuccin.lua and shared with ge's float.
      hover = {
        border = { style = "rounded", padding = { 0, 1 } },
        -- the border takes the row above the body: row 2 keeps the border
        -- off the cursor line
        position = { row = 2, col = 0 },
        win_options = {
          winhighlight = { Normal = "CursorPopup", FloatBorder = "CursorPopupBorder" },
          -- a single line of margin when scrolling long docs
          scrolloff = 1,
        },
      },
    },
  },
}
