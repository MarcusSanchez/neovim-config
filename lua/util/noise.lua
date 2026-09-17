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

---@param src string file contents
---@param row integer 1-based
---@param col integer 0-based
local function rust_in_test(src, row, col)
  local ok, parser = pcall(vim.treesitter.get_string_parser, src, "rust")
  if not ok then
    return false
  end
  local tree = parser:parse()[1]
  local node = tree and tree:root():named_descendant_for_range(row - 1, col, row - 1, col)
  while node do
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

--- Is the code at file:row:col test/generated noise? `lines` are the file's
--- lines when the caller already has them (saves a re-read).
---@param file string
---@param row? integer 1-based
---@param col? integer 0-based
---@param lines? string[]
---@return boolean
function M.is_noise(file, row, col, lines)
  file = vim.fs.normalize(file)
  if M.is_noisy_path(file) then
    return true
  end
  if row and file:match("%.rs$") then
    if not lines then
      local b = vim.fn.bufnr(file)
      lines = b > 0 and vim.api.nvim_buf_is_loaded(b) and vim.api.nvim_buf_get_lines(b, 0, -1, false)
        or vim.fn.readfile(file)
    end
    return rust_in_test(table.concat(lines, "\n"), row, col or 0)
  end
  return false
end

return M
