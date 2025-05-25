-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
vim.cmd.highlight("DiagnosticUnderlineError guisp=#ff0000 gui=undercurl")

vim.opt.whichwrap:append("h,l")
