return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      gopls = {
        settings = {
          gopls = {
            analyses = {
              shadow = true,
              unusedwrite = false,
            },
            usePlaceholders = false,
          },
        },
      },
    },
  },
}
