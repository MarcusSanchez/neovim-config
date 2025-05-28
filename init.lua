-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
vim.cmd.highlight("DiagnosticUnderlineError guisp=#ff0000 gui=undercurl")

vim.opt.whichwrap:append("h,l")

vim.diagnostic.config({
  virtual_text = {
    severity = { min = vim.diagnostic.severity.ERROR },
  },
  signs = {
    severity = { min = vim.diagnostic.severity.WARN },
  },
  jump = {
    severity = { min = vim.diagnostic.severity.WARN },
  },
})
