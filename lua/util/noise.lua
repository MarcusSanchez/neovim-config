-- Shared "is this code noise?" rules for symbol/usage searches: generated
-- files, build output, dependency trees and test code, matched by path; plus a
-- structural check for languages whose tests live inside the source file
-- (rust's `#[cfg(test)] mod tests` / `#[test] fn`).
local M = {}

-- lua patterns matched against the normalized path
M.path_patterns = {
  "%.pb%.go$",
  "%.connect%.go$",
  "%.gen%.go$",
  "%.d%.ts$",
  "_gen%.go$",
  "_generated%.go$",
  "/gen/",
  "/node_modules/",
  "/ent/",
  -- build output
  "/%.next/",
  "/%.nuxt/",
  "/%.output/",
  "/%.svelte%-kit/",
  "/%.turbo/",
  "/dist/",
  "/build/",
  "/target/",
  "/vendor/",
  "/coverage/",
  -- tests
  "_test%.go$",
  "%.test%.[jt]sx?$",
  "%.spec%.[jt]sx?$",
  "/tests/", -- rust integration tests
  "/benches/",
}

-- handwritten islands inside otherwise-noisy trees
M.handwritten_patterns = {
  "/ent/schema/",
}

---@param file string
---@return boolean
function M.is_noisy_path(file)
  for _, pat in ipairs(M.handwritten_patterns) do
    if file:match(pat) then
      return false
    end
  end
  for _, pat in ipairs(M.path_patterns) do
    if file:match(pat) then
      return true
    end
  end
  return false
end

-- rust: attributes are *siblings* preceding an item, not children, so for each
-- ancestor item of the position look back over the attribute_items in front of
-- it for `#[cfg(test)]` / `#[test]`
local function rust_attr_is_test(node, src)
  local text = vim.treesitter.get_node_text(node, src)
  return text:find("^#%[%s*test%s*%]") ~= nil or text:find("cfg%s*%(%s*test%s*%)") ~= nil
end

---@param root TSNode
---@param src string file contents
---@param row integer 1-based
---@param col integer 0-based
local function rust_in_test(root, src, row, col)
  local node = root:named_descendant_for_range(row - 1, col, row - 1, col)
  while node do
    -- landed on the attribute itself (symbol ranges can start at `#[test]`)
    if node:type() == "attribute_item" and rust_attr_is_test(node, src) then
      return true
    end
    if node:type():find("_item$") then
      local prev = node:prev_named_sibling()
      while prev and prev:type() == "attribute_item" do
        if rust_attr_is_test(prev, src) then
          return true
        end
        prev = prev:prev_named_sibling()
      end
    end
    node = node:parent()
  end
  return false
end

--- The file's lines, from its buffer when one is loaded (unsaved edits
--- included), else from disk.
---@param file string
---@return string[]
function M.file_lines(file)
  local b = vim.fn.bufnr(file)
  if b > 0 and vim.api.nvim_buf_is_loaded(b) then
    return vim.api.nvim_buf_get_lines(b, 0, -1, false)
  end
  return vim.fn.readfile(file)
end

--- Returns an `is_noise(file, row?, col?, lines?)` function that caches file
--- contents and parse trees, for callers that check many positions at once
--- (symbol search, usage lists).
function M.checker()
  local lines_cache = {} ---@type table<string, string[]>
  local root_cache = {} ---@type table<string, TSNode|false>
  local src_cache = {} ---@type table<string, string>

  local function file_lines(file, lines)
    if lines then
      return lines
    end
    if not lines_cache[file] then
      lines_cache[file] = M.file_lines(file)
    end
    return lines_cache[file]
  end

  ---@param file string
  ---@param row? integer 1-based
  ---@param col? integer 0-based
  ---@param lines? string[] the file's lines when the caller already has them
  ---@return boolean
  return function(file, row, col, lines)
    file = vim.fs.normalize(file)
    if M.is_noisy_path(file) then
      return true
    end
    if not (row and file:match("%.rs$")) then
      return false
    end
    if root_cache[file] == nil then
      local src = table.concat(file_lines(file, lines), "\n")
      local ok, parser = pcall(vim.treesitter.get_string_parser, src, "rust")
      local tree = ok and parser:parse()[1]
      root_cache[file] = tree and tree:root() or false
      src_cache[file] = src
    end
    local root = root_cache[file]
    return root and rust_in_test(root, src_cache[file], row, col or 0) or false
  end
end

--- Is the code at file:row:col test/generated noise? One-shot form of
--- M.checker(); pass `lines` when the caller already has the file's lines.
---@param file string
---@param row? integer 1-based
---@param col? integer 0-based
---@param lines? string[]
---@return boolean
function M.is_noise(file, row, col, lines)
  return M.checker()(file, row, col, lines)
end

return M
