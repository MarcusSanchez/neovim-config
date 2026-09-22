-- gs: workspace symbol search minus the noise. Like <leader>sS, but drops
-- symbols outside the project root, names the server only fuzzy-matched, and
-- test/generated code (lua/util/noise.lua).
local M = {}

function M.search()
  -- gopls also reports symbols from dependency sources (module cache in
  -- ~/go/pkg/mod, stdlib in GOROOT); only keep files under the project root
  local root = vim.fs.normalize(LazyVim.root()) .. "/"
  local is_noise = require("util.noise").checker()
  Snacks.picker.lsp_workspace_symbols({
    transform = function(item, ctx)
      if not item.file then
        return
      end
      local file = vim.fs.normalize(item.file)
      if file:sub(1, 1) == "/" and file:sub(1, #root) ~= root then
        return false
      end
      -- servers fuzzy-match the query (rust-analyzer as a loose subsequence,
      -- so "open" also returns OptionEnv); only keep names that actually
      -- contain what was typed. A path query keeps its last segment.
      local query = (ctx.filter.search or ""):match("[^:%.]*$") or ""
      if query ~= "" and not (item.name or ""):lower():find(query:lower(), 1, true) then
        return false
      end
      -- rust tests live inside the source file, so check the position too
      if is_noise(file, item.pos and item.pos[1], item.pos and item.pos[2]) then
        return false
      end
    end,
  })
end

return M
