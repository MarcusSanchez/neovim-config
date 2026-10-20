-- Buffer tabs: Alt+h/l cycle buffers, the tabline shows what's open;
-- harpoon (plugins/harpoon.lua) pins slots alongside. The row is
-- underlined edge to edge in the sidebar's border colour, so the bar
-- reads as boxed the way the explorer is (a tabline is one row, so the
-- line is an underline on every group the bar draws with).

--- Every group underlined in the sidebar border's colour, on top of the
--- theme's groups (catppuccin's, set by LazyVim) — bufferline calls this
--- with its defaults whenever it sets its highlights, colorscheme changes
--- included.
local function underlined(theme)
  return function(defaults) -- bufferline's whole default config
    local hl = type(theme) == "function" and theme(defaults) or vim.deepcopy(theme or {})
    local sp = vim.api.nvim_get_hl(0, { name = "SnacksPickerBorder", link = false }).fg
    for name in pairs(defaults.highlights) do
      hl[name] = vim.tbl_extend("force", hl[name] or {}, { underline = true, sp = sp })
    end
    return hl
  end
end

return {
  "akinsho/bufferline.nvim",
  opts = function(_, opts)
    opts.highlights = underlined(opts.highlights)
    -- LazyVim reserves the tabline above the snacks explorer (an "offset")
    -- but gives it no highlight, so bufferline guesses one from the
    -- explorer window's winhighlight: SnacksNormal, whose background is
    -- opaque (transparency here covers Normal, not the float groups) — a
    -- dark box above the sidebar, whenever the guess happens to land.
    -- Pin it to the bar's own fill so it always matches.
    for _, offset in ipairs(opts.options and opts.options.offsets or {}) do
      if offset.filetype == "snacks_layout_box" or offset.filetype == "neo-tree" then
        offset.highlight = "BufferLineFill"
        offset.separator = false
        offset.text = ""
      end
    end
  end,
}
