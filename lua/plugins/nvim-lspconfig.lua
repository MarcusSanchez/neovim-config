local zls = (jit.os == "OSX") and {} or { cmd = { "C:\\Users\\thatm\\zls\\zig-out\\bin\\zls.exe" } }

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

      zls = zls,
    },
  },
}
