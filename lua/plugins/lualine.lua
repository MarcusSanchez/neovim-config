-- Bubbles-style statusline modeled on the catppuccin/nvim README screenshot:
-- rounded mode pill + progress/location on the left, solid bar with diagnostic
-- dots in the middle, then LSP indicator and filename/cwd pills on the right.
-- opts is a function so it fully replaces LazyVim's default lualine config
-- instead of merging with it.
--
-- NOTE: separator/icon glyphs are written as \u{} escapes on purpose — the
-- private-use-area characters (nerd font powerline caps) don't survive every
-- editor/tool roundtrip, and lualine silently draws hard corners when a
-- separator is an empty string.
return {
  "nvim-lualine/lualine.nvim",
  opts = function()
    local palette = require("catppuccin.palettes").get_palette("mocha")

    -- The bar matches the cursor-line background so it reads as part of the
    -- editor rather than a detached slab (read live, works with transparency).
    local cursorline = vim.api.nvim_get_hl(0, { name = "CursorLine", link = false })
    local bar_bg = cursorline.bg and ("#%06x"):format(cursorline.bg) or palette.surface0

    -- Only a/b/c are themeable per mode; the right-side pills set their own
    -- colors per component so they don't change with the mode.
    -- NOTE: section c must have a real bg (not "NONE") — lualine skips the
    -- rounded separator caps when it can't resolve the transition color.
    local bubbles = {
      normal = {
        a = { fg = palette.base, bg = palette.lavender, gui = "bold" },
        b = { fg = palette.text, bg = palette.surface0 },
        c = { fg = palette.text, bg = bar_bg },
      },
      insert = { a = { fg = palette.base, bg = palette.green, gui = "bold" } },
      visual = { a = { fg = palette.base, bg = palette.mauve, gui = "bold" } },
      replace = { a = { fg = palette.base, bg = palette.red, gui = "bold" } },
      command = { a = { fg = palette.base, bg = palette.peach, gui = "bold" } },
      terminal = { a = { fg = palette.base, bg = palette.teal, gui = "bold" } },
      inactive = {
        a = { fg = palette.overlay0, bg = bar_bg },
        b = { fg = palette.overlay0, bg = bar_bg },
        c = { fg = palette.overlay0, bg = bar_bg },
      },
    }

    local cap_left = "\u{e0b6}" --
    local cap_right = "\u{e0b4}" --
    local pill = { left = cap_left, right = cap_right }

    return {
      options = {
        theme = bubbles,
        icons_enabled = true,
        component_separators = "",
        section_separators = { left = cap_right, right = cap_left },
        globalstatus = true,
      },
      sections = {
        lualine_a = {
          { "mode", icon = "\u{e62b}", separator = pill, padding = { left = 1, right = 2 } },
        },
        lualine_b = { "progress", { "location", separator = { right = cap_right } } },
        lualine_c = {
          "%=",
          {
            "diagnostics",
            symbols = { error = "● ", warn = "● ", info = "● ", hint = "● " },
          },
        },
        lualine_x = {
          {
            function()
              if #vim.lsp.get_clients({ bufnr = 0 }) > 0 then
                return "\u{f048b} Lsp"
              end
              return ""
            end,
            color = { fg = palette.overlay1 },
          },
        },
        lualine_y = {
          {
            "filetype",
            icon_only = true,
            separator = { left = cap_left },
            padding = { left = 1, right = 0 },
            color = { fg = palette.base, bg = palette.maroon },
          },
          {
            "filename",
            separator = { right = cap_right },
            padding = { left = 0, right = 1 },
            color = { fg = palette.base, bg = palette.maroon },
          },
        },
        lualine_z = {
          {
            function()
              return "\u{f0256} " .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
            end,
            separator = pill,
            color = { fg = palette.base, bg = palette.flamingo },
          },
        },
      },
    }
  end,
}
