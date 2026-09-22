-- gd / gh: goto-definition that falls through to usages, and the tagstack
-- pop that walks back.
local M = {}

local TITLE = "Goto Definition"

--- Is the LSP position inside the range? (both in the same client encoding;
--- the end bound is lenient so a cursor sitting right after the name counts)
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

--- Do any of the definition results cover the cursor itself?
---@param results table<integer, { result: any }> client_id -> response
---@param uri string current buffer's uri
---@param position_params fun(client: vim.lsp.Client): table
local function on_own_definition(results, uri, position_params)
  for client_id, res in pairs(results) do
    local client = vim.lsp.get_client_by_id(client_id)
    -- Location | Location[] | LocationLink[]
    local locs = res.result or {}
    locs = vim.islist(locs) and locs or { locs }
    for _, loc in ipairs(locs) do
      local range = loc.targetSelectionRange or loc.range
      if client and (loc.targetUri or loc.uri) == uri and range then
        if in_range(position_params(client).position, range) then
          return true
        end
      end
    end
  end
  return false
end

---@class util.goto.Usage
---@field file string normalized path
---@field row integer 1-based
---@field text string trimmed source line

--- Distinct reference locations, split into real usages and test/generated
--- noise (lua/util/noise.lua).
---@param results table<integer, { result: lsp.Location[]? }>
---@return util.goto.Usage[] usages, util.goto.Usage[] noisy
local function collect_usages(results)
  local noise = require("util.noise")
  local is_noise = noise.checker()
  local seen, usages, noisy = {}, {}, {}
  local lines = {} ---@type table<string, string[]>
  for _, res in pairs(results) do
    for _, loc in ipairs(res.result or {}) do
      local row, col = loc.range.start.line + 1, loc.range.start.character
      local file = vim.fs.normalize(vim.uri_to_fname(loc.uri))
      local key = ("%s:%d:%d"):format(file, row, col)
      if not seen[key] then
        seen[key] = true
        lines[file] = lines[file] or noise.file_lines(file)
        local usage = { file = file, row = row, text = vim.trim(lines[file][row] or "") }
        local bucket = is_noise(file, row, col, lines[file]) and noisy or usages
        bucket[#bucket + 1] = usage
      end
    end
  end
  return usages, noisy
end

--- IntelliJ-style "show usages": a small popup right under the cursor
--- listing file:row and the usage line, no input or preview. Opens in normal
--- mode on the list so j/k + <cr> picks one; a single usage auto-confirms.
---@param word string symbol under the cursor
---@param usages util.goto.Usage[]
---@param tests_only boolean every usage is test/generated code
local function show_usages(word, usages, tests_only)
  local count = #usages
  -- the popup hugs its widest "file:row  code" row
  local keep, width = {}, 0
  for _, u in ipairs(usages) do
    keep[u.file .. ":" .. u.row] = true
    width = math.max(width, #vim.fn.fnamemodify(u.file, ":t") + #tostring(u.row) + 3 + vim.fn.strdisplaywidth(u.text))
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
    local msg = tests_only and "Only usage of `%s` is in test/generated code" or "Only usage of `%s`"
    vim.notify(msg:format(word), vim.log.levels.INFO, { title = TITLE })
  end
end

--- gd. On a symbol's own definition (where a plain gd would just land where
--- it already is) fall through to its references: a single usage jumps
--- straight there with a notice, several open the usages popup. Anywhere
--- else this is the stock jump.
function M.definition_or_references()
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local uri = vim.uri_from_bufnr(buf)
  local word = vim.fn.expand("<cword>")

  local function position_params(client)
    return vim.lsp.util.make_position_params(win, client.offset_encoding)
  end

  vim.lsp.buf_request_all(buf, "textDocument/definition", position_params, function(results)
    if not on_own_definition(results, uri, position_params) then
      return vim.lsp.buf.definition()
    end
    if #vim.lsp.get_clients({ bufnr = buf, method = "textDocument/references" }) == 0 then
      return vim.notify("No LSP client supports references here", vim.log.levels.WARN, { title = TITLE })
    end

    vim.lsp.buf_request_all(buf, "textDocument/references", function(client)
      local params = position_params(client)
      params.context = { includeDeclaration = false }
      return params
    end, function(ref_results)
      local usages, noisy = collect_usages(ref_results)
      if #usages + #noisy == 0 then
        return vim.notify(("No references to `%s`"):format(word), vim.log.levels.WARN, { title = TITLE })
      end
      -- test/generated usages are set aside unless that's all there is
      local tests_only = #usages == 0
      show_usages(word, tests_only and noisy or usages, tests_only)
    end)
  end)
end

--- gh. Every LSP jump (gd, the usages popup, gr/gI/gy, <C-]>) pushes where it
--- came from onto the tagstack; pop the newest — the stock <C-t>, minus the
--- E73 error when the stack runs dry.
function M.back()
  if vim.fn.gettagstack().curidx <= 1 then
    return vim.notify("No jump to go back to", vim.log.levels.WARN, { title = "Go Back" })
  end
  local ok, err = pcall(vim.cmd.pop)
  if not ok then
    vim.notify(tostring(err), vim.log.levels.ERROR, { title = "Go Back" })
  end
end

return M
