-- Oil edits the filesystem like a buffer: rename a line to rename a file,
-- add a line (end with / for a directory) to create, delete a line to delete.
-- Changes only apply on :w. Inside oil: <CR> enters a directory, - goes up,
-- g? shows all mappings.
return {
  "stevearc/oil.nvim",
  -- load at startup so `nvim <dir>` opens oil instead of netrw
  lazy = false,
  opts = {
    default_file_explorer = true,
    delete_to_trash = true,
    -- merged with oil's default buffer-local maps (<C-c> also closes)
    keymaps = {
      ["q"] = "actions.close",
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
      "<leader>e",
      function()
        require("oil").open_float(LazyVim.root())
      end,
      desc = "Open Project Root (Oil Float)",
    },
  },
}
