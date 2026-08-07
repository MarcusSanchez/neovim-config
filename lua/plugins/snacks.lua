return {
  "folke/snacks.nvim",
  keys = {
    -- Drop the explorer keymaps that LazyVim's snacks_explorer extra adds;
    -- oil.nvim handles file browsing now.
    { "<leader>e", false },
    { "<leader>E", false },
    { "<leader>fe", false },
    { "<leader>fE", false },
    -- {
    --   "<leader>db",
    --   function()
    --     Snacks.dashboard()
    --   end,
    --   desc = "Open Snacks Dashboard",
    -- },
  },
  opts = {
    -- No start screen, no sidebar — just an empty buffer on launch.
    dashboard = { enabled = false },
    explorer = { enabled = false },
    picker = {
      win = {
        input = {
          keys = {
            ["k"] = "list_down",
            ["j"] = "list_up",
          },
        },
        list = {
          keys = {
            ["k"] = "list_down",
            ["j"] = "list_up",
          },
        },
      },
      -- Old explorer-as-right-sidebar config, kept for easy revert.
      -- Uncomment this (and flip explorer.enabled back to true above, and
      -- re-enable the <leader>e/<leader>fe keys) to bring it back.
      -- sources = {
      --   explorer = {
      --     -- show the explorer as a sidebar on the right
      --     layout = { layout = { position = "right" } },
      --     actions = {
      --       -- <Esc> hands focus back to the editor instead of closing the
      --       -- explorer. picker.main is the last real (non-picker) file window.
      --       focus_editor = function(picker)
      --         picker:norm(function()
      --           local main = picker.main
      --           if main and vim.api.nvim_win_is_valid(main) then
      --             vim.api.nvim_set_current_win(main)
      --           end
      --         end)
      --       end,
      --     },
      --     win = {
      --       input = { keys = { ["<Esc>"] = { "focus_editor", mode = { "n", "i" } } } },
      --       list = { keys = { ["<Esc>"] = "focus_editor" } },
      --       preview = { keys = { ["<Esc>"] = "focus_editor" } },
      --     },
      --   },
      -- },
    },
  },
}
