return {
  "folke/snacks.nvim",
  keys = {
    -- LazyVim's default explorer keys (<leader>e/E/fe/fE) are live again —
    -- the oil-era `= false` disables are kept below for the next experiment.
    -- { "<leader>e", false },
    -- { "<leader>E", false },
    -- { "<leader>fe", false },
    -- { "<leader>fE", false },
    {
      "<leader>db",
      function()
        Snacks.dashboard()
      end,
      desc = "Open Snacks Dashboard",
    },
  },
  opts = {
    -- dashboard config lives in dashboard.lua; explorer rides as the right
    -- sidebar below. (The oil/harpoon experiment disabled both, 2026-08-13
    -- reverted.)
    explorer = { enabled = true },
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
        -- grep literally: typing `foo(` or `a.b` finds exactly that, no
        -- escaping. (grep_word is already fixed-strings; <leader>sr's
        -- grug-far keeps regex since replacements lean on it.)
        grep = { regex = false },
        grep_buffers = { regex = false },
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
