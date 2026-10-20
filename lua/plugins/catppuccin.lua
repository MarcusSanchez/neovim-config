-- Catppuccin Mocha, transparent, with highlights tracking a GoLand scheme.
-- These opts merge into LazyVim's catppuccin spec (its integrations and
-- undercurls stay); LazyVim loads the colorscheme named below at startup.
return {
  { "LazyVim/LazyVim", opts = { colorscheme = "catppuccin-mocha" } },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "mocha",
      transparent_background = true,
      highlight_overrides = {
        all = function(colors)
          local fall = "#dabb9b"
          local cherry_blossom = "#ff6ca9"

          return {
            ["@keyword"] = { fg = colors.mauve, style = { "italic" } },
            -- true/false and nil/null/undefined read as keywords rather than
            -- constants, matching the GoLand scheme these overrides track;
            -- catppuccin would otherwise leave both on peach
            ["@boolean"] = { fg = colors.mauve, style = { "italic" } },
            ["@constant.builtin"] = { fg = colors.mauve, style = { "italic" } },
            ["@function.builtin"] = { fg = colors.blue },
            ["@property"] = { fg = colors.red },
            ["@module"] = { fg = colors.subtext1, style = { "italic" } },
            ["@variable"] = { fg = colors.subtext1 },
            ["@variable.member"] = { fg = colors.red },
            ["@variable.parameter"] = { fg = fall },
            ["@number"] = { fg = colors.sky },
            ["@operator"] = { fg = cherry_blossom },
            ["@type"] = { fg = colors.yellow },
            ["@punctuation.delimiter"] = { fg = colors.overlay2 },
            ["@punctuation.special"] = { fg = cherry_blossom },
            ["@lsp.type.enumMember"] = { fg = colors.peach },
            -- treesitter-context: shade the pinned scope line's background so
            -- it reads as a distinct bar, no underline/separator needed (the
            -- separator-row experiment is commented in nvim-treesitter-context.lua)
            -- hand-tuned hex: just a whisker above mocha base (#1e1e2e), the
            -- faintest shade that still separates the bar from the background
            TreesitterContext = { bg = "#232334" },
            TreesitterContextLineNumber = { bg = "#232334" },
            TreesitterContextBottom = { style = {} },
            TreesitterContextLineNumberBottom = { style = {} },

            -- the ` ... }` a closed fold shows (lua/util/foldtext.lua)
            FoldEllipsis = { fg = colors.overlay1 },
            FoldCursor = { fg = colors.base, bg = colors.text }, -- the caret on a closed fold

            -- snacks picker / explorer
            -- transparent_background only covers Normal, not NormalFloat, so the
            -- picker windows end up sitting on an opaque mantle slab. Every
            -- SnacksPicker* group links down to these four, so overriding the
            -- roots covers the input, list, preview and box windows too.
            SnacksPicker = { fg = colors.text, bg = "NONE" },
            -- …except the input box, which links to NormalFloat on its own
            SnacksPickerInput = { fg = colors.text, bg = "NONE" },
            SnacksPickerBorder = { fg = colors.blue, bg = "NONE" },
            SnacksPickerTitle = { fg = colors.subtext0, bg = "NONE" },
            SnacksPickerFooter = { fg = colors.subtext0, bg = "NONE" },

            -- cursor popups (gk hover via noice.lua, ge diagnostics via
            -- keymaps.lua): same transparent body + blue rounded border as
            -- the pickers
            CursorPopup = { fg = colors.text, bg = "NONE" },
            CursorPopupBorder = { fg = colors.blue, bg = "NONE" },

            -- golang
            ["@lsp.typemod.variable.defaultLibrary.go"] = { fg = colors.peach },
            -- shadowed variables get a color instead of the info squiggle
            -- (the shadow diagnostic itself is dropped in autocmds.lua)
            ["@lsp.typemod.variable.shadowing.go"] = { fg = "#DEBABA" },
            ["@lsp.typemod.variable.readonly.go"] = { fg = colors.peach },
            ["@lsp.type.namespace.go"] = { fg = colors.subtext1, style = { "italic" } },
            ["@lsp.type.parameter.go"] = { fg = fall },
            ["@lsp.typemod.variable.member.go"] = { fg = colors.red },
            ["@lsp.typemod.variable.declaration.go"] = { fg = colors.red },
            ["@variable.member.go"] = { fg = colors.red },
            ["@lsp.mod.format.go"] = { fg = colors.pink },
            ["@lsp.typemod.string.format.go"] = { fg = colors.pink },

            -- JS/TS/JSX/TSX
            ["@keyword.operator.tsx"] = { fg = colors.mauve },
            ["@tag.builtin"] = { fg = colors.red },
            ["@tag.attribute"] = { fg = fall },
            ["@tag.attribute.tsx"] = { fg = fall },
            ["@tag.tsx"] = { fg = colors.yellow },
            ["@tag.delimiter"] = { link = "@punctuation.bracket" },
            ["@lsp.type.interface.typescript"] = { fg = colors.yellow },
            ["@keyword.operator.typescript"] = { fg = colors.mauve },
            ["@string.special.url.tsx"] = { fg = colors.green, style = { "underline" } },

            -- gleam
            ["@label.gleam"] = { fg = colors.red },
            ["@constructor.gleam"] = { fg = colors.yellow },

            -- protobuf
            ["@lsp.type.variable.proto"] = { fg = colors.red },

            -- rust
            ["@lsp.type.macro.rust"] = { fg = colors.blue },
            -- treesitter captures every path qualifier as @module, so a type
            -- used as one (`Dongle::open()`) inherited the namespace italic
            -- even under rust-analyzer's struct token (attributes combine;
            -- a token can't un-italic). Keep the capture upright and let
            -- the semantic token say which qualifiers are real modules.
            ["@module.rust"] = { fg = colors.yellow, style = {} },
            ["@lsp.type.namespace.rust"] = { fg = colors.yellow, style = { "italic" } },

            -- zig
            ["@keyword.import.zig"] = { fg = colors.blue },
          }
        end,
      },
    },
  },
}
