-- neo-tree as the sidebar (on trial from 2026-10-11, replacing the snacks
-- explorer; lua/util/explorer.lua is the switch). LazyVim's extra supplies
-- the sources, l/h open/close, Y copies the path, P previews; this puts it
-- on the right like the old sidebar and hands focus back on <Esc>.
return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    close_if_last_window = false, -- the QuitPre autocmd handles :q on the last window
    popup_border_style = "rounded",
    window = {
      position = "right",
      width = 40,
      mappings = {
        -- back to the editor, as the snacks explorer did
        ["<esc>"] = {
          function()
            vim.cmd.wincmd("p")
          end,
          desc = "Focus Editor",
        },
      },
    },
    filesystem = {
      filtered_items = {
        visible = true, -- show hidden/ignored files, dimmed
        hide_dotfiles = false,
        hide_gitignored = true,
      },
    },
  },
}
