return {
  "folke/snacks.nvim",
  keys = {
    {
      "<leader>db",
      function()
        Snacks.dashboard()
      end,
      desc = "Open Snacks Dashboard",
    },
  },
  opts = {
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
      sources = {
        explorer = {
          -- show the explorer as a sidebar on the right
          layout = { layout = { position = "right" } },
          actions = {
            -- <Esc> hands focus back to the editor instead of closing the
            -- explorer. picker.main is the last real (non-picker) file window.
            focus_editor = function(picker)
              picker:norm(function()
                local main = picker.main
                if main and vim.api.nvim_win_is_valid(main) then
                  vim.api.nvim_set_current_win(main)
                end
              end)
            end,
          },
          win = {
            input = { keys = { ["<Esc>"] = { "focus_editor", mode = { "n", "i" } } } },
            list = { keys = { ["<Esc>"] = "focus_editor" } },
            preview = { keys = { ["<Esc>"] = "focus_editor" } },
          },
        },
      },
    },
  },
}
