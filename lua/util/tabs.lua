-- Tab bar (bufferline) styles, switchable at runtime to compare:
--   attached  a baseline runs along the bar and breaks under the active tab,
--             which has thin walls and a tint — the tab opens into the editor
--   accent    a coloured underline marks the active tab (IntelliJ / Zed)
-- Both are one-row designs: the tabline can't draw a top edge.
local M = {}

M.styles = { "attached", "accent" }
M.current = vim.g.tab_style or "attached"

local function palette()
  return require("catppuccin.palettes").get_palette("mocha")
end

--- bufferline's full list of highlight groups, from the config it merged
--- at its first setup (config.get() is the whole config object).
local function group_names()
  local ok, config = pcall(require, "bufferline.config")
  local merged = ok and config.get and config.get()
  local hls = type(merged) == "table" and merged.highlights
  if type(hls) == "table" and next(hls) then
    return vim.tbl_keys(hls)
  end
  return {}
end

---@return table highlights, table options
local function attached()
  local c = palette()
  local line, tint = c.overlay0, c.surface0
  local hl = {}
  for _, name in ipairs(group_names()) do
    if name:find("_selected$") then
      hl[name] = { bg = tint, underline = false }
    else
      hl[name] = { bg = "NONE", underline = true, sp = line }
    end
  end
  -- text colours on top of the structure above
  local text = {
    fill = {},
    background = { fg = c.overlay1 },
    buffer_visible = { fg = c.subtext0 },
    buffer_selected = { fg = c.text, bold = false, italic = false },
    separator = { fg = line },
    modified = { fg = c.peach },
    modified_visible = { fg = c.peach },
    modified_selected = { fg = c.peach },
    close_button = { fg = c.overlay1 },
    close_button_visible = { fg = c.subtext0 },
    close_button_selected = { fg = c.subtext0 },
    -- the active tab's left wall: outside the tint, no baseline under it
    indicator_selected = { fg = line, bg = "NONE", underline = false },
    duplicate = { fg = c.overlay1, italic = true },
    duplicate_visible = { fg = c.subtext0, italic = true },
    duplicate_selected = { fg = c.subtext1, italic = true },
  }
  for name, attrs in pairs(text) do
    hl[name] = vim.tbl_extend("force", hl[name] or {}, attrs)
  end
  return hl,
    {
      indicator = { style = "icon", icon = "▏" },
      -- after the active tab: a wall hugging it; after the others: a divider
      separator_style = { "▏", "│" },
      show_buffer_close_icons = true,
    }
end

---@return table highlights, table options
local function accent()
  local c = palette()
  local hl = {}
  for _, name in ipairs(group_names()) do
    if name:find("_selected$") then
      hl[name] = { bg = c.surface0, sp = c.lavender, underline = true }
    else
      hl[name] = { bg = "NONE", underline = false }
    end
  end
  local text = {
    background = { fg = c.overlay1 },
    buffer_visible = { fg = c.subtext0 },
    buffer_selected = { fg = c.text, bold = false, italic = false },
    separator = { fg = c.surface1 },
    modified = { fg = c.peach },
    modified_visible = { fg = c.peach },
    modified_selected = { fg = c.peach },
    close_button = { fg = c.overlay1 },
    close_button_visible = { fg = c.subtext0 },
    close_button_selected = { fg = c.subtext0 },
    duplicate = { fg = c.overlay1, italic = true },
    duplicate_visible = { fg = c.subtext0, italic = true },
    duplicate_selected = { fg = c.subtext1, italic = true },
  }
  for name, attrs in pairs(text) do
    hl[name] = vim.tbl_extend("force", hl[name] or {}, attrs)
  end
  return hl,
    {
      indicator = { style = "underline" },
      separator_style = { "│", "│" },
      show_buffer_close_icons = true,
    }
end

local builders = { attached = attached, accent = accent }

--- Apply a style on top of the spec's bufferline opts (LazyVim's merged
--- with ours) and re-run setup so it takes effect immediately.
---@param style? string
function M.apply(style)
  style = style or M.current
  assert(builders[style], "unknown tab style: " .. tostring(style))
  M.current, vim.g.tab_style = style, style
  local plugin = require("lazy.core.config").plugins["bufferline.nvim"]
  local base = require("lazy.core.plugin").values(plugin, "opts", false)
  local highlights, options = builders[style]()
  -- bufferline defines its groups as defaults, which never override groups
  -- that already exist — so a re-setup would change nothing. Clear ours
  -- first (a colorscheme switch does the same for it).
  for _, name in ipairs(vim.fn.getcompletion("BufferLine", "highlight")) do
    vim.api.nvim_set_hl(0, name, {})
  end
  require("bufferline").setup(vim.tbl_deep_extend("force", base, {
    options = options,
    highlights = highlights,
  }))
  vim.cmd.redrawtabline()
end

function M.toggle()
  local i = M.current == "attached" and 2 or 1
  M.apply(M.styles[i])
  vim.notify("Tab style: " .. M.current, vim.log.levels.INFO, { title = "Tabs" })
end

return M
