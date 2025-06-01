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

      tailwindcss = {
        filetypes_include = {
          "tailwind.config.js",
        },
      },

      zls = {
        enable_build_on_save = true,
        build_on_save_args = { "install" },
      },
    },
  },
}
