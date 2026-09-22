-- same shape as LazyVim's term_nav (plugins/util.lua): in a floating
-- terminal the key is passed through, otherwise focus moves to that window
local function term_nav(dir)
  ---@param self snacks.terminal
  return function(self)
    return self:is_floating() and "<c-" .. dir .. ">" or vim.schedule(function()
      vim.cmd.wincmd(dir)
    end)
  end
end

return {
  "folke/snacks.nvim",
  keys = {
    -- (to bench the explorer again, see lua/benched/oil.lua)
    {
      "<leader>db",
      function()
        Snacks.dashboard()
      end,
      desc = "Open Snacks Dashboard",
    },
  },
  opts = {
    terminal = {
      win = {
        keys = {
          -- LazyVim's term_nav, with j/k swapped: <C-j> goes up, <C-k> down
          nav_j = { "<C-j>", term_nav("k"), desc = "Go to Upper Window", expr = true, mode = "t" },
          nav_k = { "<C-k>", term_nav("j"), desc = "Go to Lower Window", expr = true, mode = "t" },
        },
      },
    },
    -- dashboard config lives in dashboard.lua; the explorer rides as the
    -- right sidebar below
    explorer = { enabled = true },
    -- j/k are swapped in this config (see config/keymaps.lua): every
    -- picker list and the terminal window nav follow suit
    picker = {
      win = {
        input = {
          keys = {
            ["k"] = "list_down",
            ["j"] = "list_up",
            ["<c-k>"] = { "list_down", mode = { "i", "n" } },
            ["<c-j>"] = { "list_up", mode = { "i", "n" } },
          },
        },
        list = {
          keys = {
            ["k"] = "list_down",
            ["j"] = "list_up",
            ["<c-k>"] = "list_down",
            ["<c-j>"] = "list_up",
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
