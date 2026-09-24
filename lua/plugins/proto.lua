-- Protobuf via buf. `buf lsp serve` (nvim-lspconfig's buf_ls) supplies
-- diagnostics — compile errors plus the module's buf lint rules — and
-- navigation, references, rename, completion and document symbols; `buf
-- format` runs on save through conform; treesitter does highlighting.
-- Breaking-change checks aren't exposed over LSP; run `buf breaking` for those.
--
-- buf comes from the project's dev shell when it has one (mason's bin dir is
-- appended to PATH, see formatting.lua); mason's copy is the fallback.
return {
  {
    "neovim/nvim-lspconfig",
    init = function()
      -- buf_ls also serves buf's own config files; nvim doesn't detect them
      vim.filetype.add({
        filename = {
          ["buf.yaml"] = "buf-config",
          ["buf.gen.yaml"] = "buf-config",
          ["buf.policy.yaml"] = "buf-config",
          ["buf.lock"] = "buf-config",
        },
      })
      vim.treesitter.language.register("yaml", "buf-config")
    end,
    opts = {
      servers = { buf_ls = {} },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "buf" } },
  },
  {
    "stevearc/conform.nvim",
    opts = { formatters_by_ft = { proto = { "buf" } } },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "proto" } },
  },
}
