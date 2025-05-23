return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  build = ":Copilot auth",
  event = "BufReadPost",
  opts = {
    suggestion = {
      enabled = true, -- Enable inline ghost text
      auto_trigger = true, -- Trigger suggestions automatically as you type
      hide_during_completion = false,
      keymap = {
        accept = "<Tab>", -- Accept Copilot suggestion with Tab (like VS Code)
        accept_word = false,
        accept_line = false,
        next = "<M-]>",
        prev = "<M-[>",
        dismiss = "<C-]>",
      },
    },
    panel = { enabled = false }, -- Disable Copilot panel
    filetypes = {
      markdown = true,
      help = true,
      -- Disable for certain filetypes if you want:
      yaml = false,
      gitcommit = false,
      gitrebase = false,
      hgcommit = false,
      svn = false,
      cvs = false,
      ["."] = false,
    },
    copilot_node_command = "node", -- Make sure your node version is >= 20
    server_opts_overrides = {},
  },
}
