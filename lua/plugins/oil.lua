-- Oil edits the filesystem like a buffer: rename a line to rename a file,
-- add a line (end with / for a directory) to create, delete a line to delete.
-- Changes only apply on :w. Inside oil: <CR> enters a directory, - goes up,
-- g? shows all mappings. Lives alongside the snacks explorer sidebar: `-`
-- opens the current file's directory in a float, `,o` the project root.
-- (Revived 2026-10-11 after being benched since 2026-08-13.)
return {
  "stevearc/oil.nvim",
  cmd = "Oil",
  opts = {
    -- `nvim <dir>` keeps opening the snacks explorer; oil is reached by key
    default_file_explorer = false,
    delete_to_trash = true,
    -- merged with oil's default buffer-local maps (<C-c> also closes)
    keymaps = {
      ["q"] = "actions.close",
      ["<Esc>"] = { "actions.close", mode = "n" },
      -- inverse of <CR>: go up to the parent directory. <S-CR> needs the kitty
      -- keyboard protocol, which Ghostty (and Neovide) support.
      ["<S-CR>"] = "actions.parent",
    },
    -- centered floating window instead of taking over the current window
    float = {
      padding = 2,
      max_width = 90,
      max_height = 30,
      border = "rounded",
    },
    view_options = {
      show_hidden = true,
    },
  },
  keys = {
    {
      "-",
      function()
        require("oil").open_float()
      end,
      desc = "Open Parent Directory (Oil Float)",
    },
    {
      ",o",
      function()
        require("oil").open_float(LazyVim.root())
      end,
      desc = "Open Project Root (Oil Float)",
    },
  },
}
