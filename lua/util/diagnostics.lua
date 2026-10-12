-- Diagnostics that shouldn't render.
local M = {}

--- gopls' `shadow` analyzer reports every shadowed variable as an info
--- diagnostic (blue squiggle + sign). Shadowed variables are already painted
--- a distinct colour through the @lsp.typemod.variable.shadowing.go
--- semantic token (plugins/catppuccin.lua), so the diagnostic is noise.
local function is_shadow(d)
  return d.source == "shadow"
    or d.code == "shadow"
    or (d.message and d.message:find("shadows declaration", 1, true) ~= nil)
end

--- Drop the shadow diagnostics before they render, whatever sets them.
function M.setup()
  local set = vim.diagnostic.set
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.diagnostic.set = function(ns, bufnr, diagnostics, opts)
    return set(
      ns,
      bufnr,
      vim.tbl_filter(function(d)
        return not is_shadow(d)
      end, diagnostics),
      opts
    )
  end
end

return M
