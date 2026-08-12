-- Match the GoLand / CI save pipeline:
--   eslint --fix        -> already handled by the eslint extra (LSP fix-all on save)
--   prettier --write    -> conform, resolved from the project (node_modules/.bin first)
--   tsc --noEmit        -> live diagnostics from vtsls, no save hook needed
--   goimports -w        -> conform, first so missing/unused imports get fixed
--   golangci-lint fmt   -> conform, last so gofumpt + gci grouping from the
--                          project's .golangci.yml decides the final layout
--   golangci-lint run   -> nvim-lint, on save
return {
  -- Mason normally *prepends* its bin dir to PATH, shadowing project tools.
  -- Append instead: binaries from the project's dev shell (the PATH nvim was
  -- launched with) win, and mason's copies are only a fallback.
  {
    "mason-org/mason.nvim",
    opts = { PATH = "append" },
  },

  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      local util = require("conform.util")

      opts.formatters = opts.formatters or {}
      -- golangci-lint v2 `fmt` runs whatever formatters the project's
      -- .golangci.yml enables (gofumpt, gci, ...). cwd is pinned to the
      -- config/module root so config discovery and gci's local-prefix
      -- detection work while editing files in nested packages.
      opts.formatters.golangci_fmt = {
        command = "golangci-lint",
        args = { "fmt", "--stdin" },
        stdin = true,
        cwd = util.root_file({ ".golangci.yml", ".golangci.yaml", ".golangci.toml", ".golangci.json", "go.mod" }),
      }

      opts.formatters_by_ft = opts.formatters_by_ft or {}
      -- goimports first (adds/removes imports), golangci-lint fmt last so the
      -- project's gci grouping has the final say on import layout — replaces
      -- the LazyVim go extra's goimports+gofumpt pair, which never matched it.
      opts.formatters_by_ft.go = { "goimports", "golangci_fmt" }

      -- conform's prettier resolves node_modules/.bin/prettier before any
      -- global one, so each project's prettier version and config are used.
      for _, ft in ipairs({ "javascript", "javascriptreact", "typescript", "typescriptreact" }) do
        opts.formatters_by_ft[ft] = { "prettier" }
      end
    end,
  },

  -- `golangci-lint run` diagnostics on save (nvim-lint is already in LazyVim
  -- core; this just adds go to its filetypes)
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        go = { "golangcilint" },
      },
    },
  },
}
