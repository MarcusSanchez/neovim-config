return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  build = ":Copilot auth",
  event = "BufReadPost",
  init = function()
    require("util.copilot").setup() -- reap servers orphaned by earlier sessions
  end,
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
    -- node >= 20, launched through a watchdog wrapper so the server can't
    -- outlive nvim (lua/util/copilot.lua)
    copilot_node_command = require("util.copilot").node_command(),
    server_opts_overrides = {
      -- a normal quit waits up to this long for the polite shutdown, then
      -- force-stops the server (nvim's default is to not wait at all). Short:
      -- :qa is held for the whole of it when the server is mid-request, and
      -- the watchdog in util/copilot.lua reaps a lingering server anyway.
      exit_timeout = 100,
    },
  },
}
