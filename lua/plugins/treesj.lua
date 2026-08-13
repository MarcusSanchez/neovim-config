-- Syntax-aware split/join: explode a one-line call/table/struct into
-- multiple lines or flatten it back. ,j toggles based on current state
-- (N still does plain line joins).
return {
  "Wansmer/treesj",
  keys = {
    {
      ",j",
      function()
        require("treesj").toggle()
      end,
      desc = "Split/Join Block (Treesitter)",
    },
  },
  -- defaults bind <space>m/j/s, which would collide with <leader>
  opts = { use_default_keymaps = false },
}
