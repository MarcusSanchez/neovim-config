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
-- straight there with a notice, several open a small "usages" popup under the
-- cursor, in normal mode, so j/k + <cr> picks one. Anywhere else gd is the
-- stock jump.
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
      -- distinct locations (two clients may report the same spot); test and
      -- generated code is set aside (lua/util/noise.lua) unless that's all
      -- there is
      local noise = require("util.noise")
      local seen, usages, noisy = {}, {}, {}
      local lines = {} ---@type table<string, string[]>
      for _, res in pairs(ref_results) do
        for _, loc in ipairs(res.result or {}) do
          local row, col = loc.range.start.line + 1, loc.range.start.character
          local fname = vim.fs.normalize(vim.uri_to_fname(loc.uri))
          local key = ("%s:%d:%d"):format(fname, row, col)
          if not seen[key] then
            seen[key] = true
            if not lines[fname] then
              local b = vim.fn.bufnr(fname)
              lines[fname] = b > 0 and vim.api.nvim_buf_is_loaded(b) and vim.api.nvim_buf_get_lines(b, 0, -1, false)
                or vim.fn.readfile(fname)
            end
            local usage = { file = fname, row = row, text = vim.trim(lines[fname][row] or "") }
            local bucket = noise.is_noise(fname, row, col, lines[fname]) and noisy or usages
            bucket[#bucket + 1] = usage
          end
        end
      end

      if #usages + #noisy == 0 then
        return vim.notify(("No references to `%s`"):format(word), vim.log.levels.WARN, { title = "LSP" })
      end
      local tests_only = #usages == 0
      if tests_only then
        usages = noisy
      end
      local count = #usages
      -- the popup hugs its widest "file:row  code" row
      local keep, width = {}, 0
      for _, u in ipairs(usages) do
        keep[u.file .. ":" .. u.row] = true
        width =
          math.max(width, #vim.fn.fnamemodify(u.file, ":t") + #tostring(u.row) + 3 + vim.fn.strdisplaywidth(u.text))
      end

      local title = ("Usages of %s%s"):format(word, tests_only and " (tests/generated only)" or "")
      Snacks.picker.lsp_references({
        title = title,
        include_declaration = false,
        -- the declaration is filtered by the request; keep a usage that
        -- happens to share the definition's line
        include_current = true,
        transform = function(item)
          if not keep[vim.fs.normalize(item.file) .. ":" .. item.pos[1]] then
            return false
          end
        end,
        auto_confirm = count == 1,
        focus = "list",
        -- IntelliJ-style "show usages": a small popup right under the cursor
        -- listing file:row and the usage line, no input or preview
        layout = {
          hidden = { "input", "preview" },
          layout = {
            relative = "cursor",
            row = 1,
            col = 0,
            width = math.min(math.max(width + 2, #title + 4), vim.o.columns - 4),
            height = math.min(count, 12),
            backdrop = false,
            border = "rounded",
            title = "{title}",
            title_pos = "left",
            box = "vertical",
            { win = "input", height = 1, border = "bottom" },
            { win = "list", border = "none" },
          },
        },
        format = function(item)
          return {
            { vim.fn.fnamemodify(item.file, ":t"), "SnacksPickerFile" },
            { ":" .. item.pos[1], "SnacksPickerRow" },
            { "  " },
            { vim.trim(item.line or ""), "SnacksPickerComment" },
          }
        end,
      })
      if count == 1 then
        local where = tests_only and "Only usage of `%s` is in test/generated code" or "Only usage of `%s`"
        vim.notify(where:format(word), vim.log.levels.INFO, { title = "LSP" })
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
