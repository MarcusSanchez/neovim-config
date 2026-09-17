-- Is the LSP position inside the range? (both in the same client encoding;
-- the end bound is lenient so a cursor sitting right after the name counts)
local function in_range(pos, range)
  local s, e = range.start, range["end"]
  if pos.line < s.line or pos.line > e.line then
    return false
  end
  if pos.line == s.line and pos.character < s.character then
    return false
  end
  if pos.line == e.line and pos.character > e.character then
    return false
  end
  return true
end

-- gd on a symbol's own definition (where a plain gd would just land where it
-- already is) falls through to its references instead: a single usage jumps
-- straight there with a notice, several open the references picker already
-- in normal mode so j/k + <cr> picks one. Anywhere else gd is the stock jump.
local function definition_or_references()
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local uri = vim.uri_from_bufnr(buf)
  local word = vim.fn.expand("<cword>")

  local function position_params(client)
    return vim.lsp.util.make_position_params(win, client.offset_encoding)
  end

  vim.lsp.buf_request_all(buf, "textDocument/definition", position_params, function(results)
    local on_definition = false
    for client_id, res in pairs(results) do
      local client = vim.lsp.get_client_by_id(client_id)
      -- Location | Location[] | LocationLink[]
      local locs = res.result or {}
      locs = vim.islist(locs) and locs or { locs }
      for _, loc in ipairs(locs) do
        local range = loc.targetSelectionRange or loc.range
        if client and (loc.targetUri or loc.uri) == uri and range then
          if in_range(position_params(client).position, range) then
            on_definition = true
          end
        end
      end
    end

    if not on_definition then
      return vim.lsp.buf.definition()
    end
    if #vim.lsp.get_clients({ bufnr = buf, method = "textDocument/references" }) == 0 then
      return vim.notify("No LSP client supports references here", vim.log.levels.WARN, { title = "LSP" })
    end

    vim.lsp.buf_request_all(buf, "textDocument/references", function(client)
      local params = position_params(client)
      params.context = { includeDeclaration = false }
      return params
    end, function(ref_results)
      -- count distinct locations (two clients may report the same spot)
      local seen, count = {}, 0
      for _, res in pairs(ref_results) do
        for _, loc in ipairs(res.result or {}) do
          local key = ("%s:%d:%d"):format(loc.uri, loc.range.start.line, loc.range.start.character)
          if not seen[key] then
            seen[key] = true
            count = count + 1
          end
        end
      end

      if count == 0 then
        return vim.notify(("No references to `%s`"):format(word), vim.log.levels.WARN, { title = "LSP" })
      end
      Snacks.picker.lsp_references({
        include_declaration = false,
        -- the declaration is filtered by the request; keep a usage that
        -- happens to share the definition's line
        include_current = true,
        auto_confirm = count == 1,
        focus = "list",
      })
      if count == 1 then
        vim.notify(("Only usage of `%s`"):format(word), vim.log.levels.INFO, { title = "LSP" })
      end
    end)
  end)
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
      servers = {
        ["*"] = {
          keys = {
            {
              "gd",
              definition_or_references,
              has = "definition",
              desc = "Goto Definition (or References)",
            },
            { "K", false }, -- disable this keymap globally
          },
        },
        -- You can specify other servers like below:
        -- lua_ls = {
        --  keys = { ... },
        -- },
      },
    },
  },
}
