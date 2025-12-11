return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
      servers = {
        ["*"] = {
          keys = {
            { "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", has = "definition" },
            { "K", false }, -- disable this keymap globally
          },
        },
        -- You can specify other servers like below:
        -- lua_ls = {
        --  keys = { ... },
        -- },
      },
    },
  },
}
