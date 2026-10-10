-- Buffer tabs (2026-08-13: the harpoon experiment is benched in
-- lua/benched/harpoon.lua). Alt+h/l cycle buffers, the tabline shows what's
-- open. The look is one of two switchable styles in lua/util/tabs.lua
-- (:TabStyle <name>; <leader>uB cycles — not <leader>uT, which LazyVim
-- uses to toggle treesitter highlighting).
return {
  "akinsho/bufferline.nvim",
  keys = {
    {
      "<leader>uB",
      function()
        require("util.tabs").toggle()
      end,
      desc = "Toggle Tab Style",
    },
  },
  config = function(_, opts)
    require("bufferline").setup(opts)
    require("util.tabs").apply()
    vim.api.nvim_create_user_command("TabStyle", function(cmd)
      require("util.tabs").apply(cmd.args ~= "" and cmd.args or nil)
    end, {
      nargs = "?",
      complete = function()
        return require("util.tabs").styles
      end,
    })
    -- Fix bufferline when restoring a session (LazyVim's config did this)
    vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete" }, {
      callback = function()
        vim.schedule(function()
          pcall(nvim_bufferline)
        end)
      end,
    })
  end,
}
