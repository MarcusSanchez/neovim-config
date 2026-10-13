-- LSP: keymaps, diagnostics display and per-server settings. The gd/gh
-- behaviour lives in lua/util/goto.lua.
return {
  "neovim/nvim-lspconfig",
  opts = {
    inlay_hints = { enabled = false },
    -- LazyVim would swap the fold expression for vim.lsp.foldexpr() as a
    -- server attaches; lua/util/foldranges.lua takes the server's ranges
    -- itself (normalised so a fold hides its closing bracket) behind one
    -- expression set in config/options.lua
    folds = { enabled = false },
    diagnostics = {
      -- only errors get virtual text; warnings and info keep their sign
      -- and underline
      virtual_text = { severity = { min = vim.diagnostic.severity.ERROR } },
    },
    servers = {
      ["*"] = {
        keys = {
          {
            "gd",
            function()
              require("util.goto").definition_or_references()
            end,
            has = "definition",
            desc = "Goto Definition (or Usages)",
          },
          {
            "gh",
            function()
              require("util.goto").back()
            end,
            desc = "Go Back (Pop Tagstack)",
          },
          { "K", false }, -- hover is on gk instead:
          { "gk", vim.lsp.buf.hover, has = "hover", desc = "LSP Hover" },
        },
      },
      gopls = {
        settings = {
          gopls = {
            analyses = {
              -- shadowed variables get a color (catppuccin.lua) instead of
              -- the info squiggle; the diagnostic is dropped in autocmds.lua
              shadow = true,
              unusedwrite = false,
            },
            usePlaceholders = false,
          },
        },
      },
      tailwindcss = {
        filetypes_include = { "tailwind.config.js" },
      },
      bashls = {}, -- shell scripts (mason's bash-language-server)
      nil_ls = {
        settings = {
          -- fetch flake inputs into the store automatically instead of asking
          -- "Fetch them now?" every session (the answer is never persisted, and
          -- fetched inputs have no GC root so nix GC keeps un-fetching them)
          ["nil"] = { nix = { flake = { autoArchive = true } } },
        },
      },
    },
  },
}
