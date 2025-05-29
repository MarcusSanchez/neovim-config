if true then
  return {}
end

return {
  "ray-x/go.nvim",
  dependencies = {
    "ray-x/guihua.lua", -- Optional, for floating windows and enhanced UI
    "neovim/nvim-lspconfig", -- LSP support
    "nvim-treesitter/nvim-treesitter", -- Treesitter for syntax highlighting
  },
  config = function()
    require("go").setup({
      lsp_inlay_hints = {
        enable = false,
      },
      lsp_cfg = {
        settings = {
          gopls = {
            analyses = {
              shadow = true,
            },
          },
        },
      },
    })
  end,
  event = { "CmdlineEnter" },
  ft = { "go", "gomod" },
  build = ':lua require("go.install").update_all_sync()', -- Installs Go binaries
}
