-- BENCHED 2026-10-11 — tried for a day; "looks pretty much the same as
-- snacks without the input at the top". To revive: move this file to
-- lua/plugins/, add "lazyvim.plugins.extras.editor.neo-tree" to
-- lazyvim.json, set vim.g.explorer = "neo-tree" (util/explorer.lua) and
-- explorer.enabled = false in plugins/snacks.lua.
--
-- LazyVim's extra supplies the sources, l/h open/close, Y copies the path,
-- P previews; this puts it on the right like the snacks sidebar and hands
-- focus back on <Esc>.
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
