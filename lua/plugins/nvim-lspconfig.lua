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
      nil_ls = {
        settings = {
          -- fetch flake inputs into the store automatically instead of asking
          -- "Fetch them now?" every session (the answer is never persisted, and
          -- fetched inputs have no GC root so nix GC keeps un-fetching them)
          ["nil"] = { nix = { flake = { autoArchive = true } } },
        },
      },
    },
  }
}
