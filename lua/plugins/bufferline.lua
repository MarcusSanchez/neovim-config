-- Buffer tabs: Alt+h/l cycle buffers, the tabline shows what's open;
-- harpoon (plugins/harpoon.lua) pins slots alongside.
return {
  "akinsho/bufferline.nvim",
  opts = function(_, opts)
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
