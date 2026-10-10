-- Tab bar (bufferline) styles, switchable at runtime to compare
-- (:TabStyle <name>, <leader>uB cycles). "classic" keeps LazyVim's default
-- tab shapes on a contained strip; the "outline" family draws the active
-- tab as a hollow pill like the gk/ge popups' border. One row only: the
-- tabline can't draw a top edge.
local M = {}

local LEFT, RIGHT = "\u{e0b7}", "\u{e0b5}" -- thin (outlined) half circles
local LEFT_FILL, RIGHT_FILL = "\u{e0b6}", "\u{e0b4}" -- filled, as the statusline pills

---@class util.tabs.Preset
---@field all? boolean outline every tab (inactive ones dim), not just the active
---@field dividers? boolean thin dividers between inactive tabs
---@field solid? boolean the active tab filled, with dark text
---@field roomy? boolean extra space inside the pill
---@field color? string palette colour for the active outline (default blue)

---@class util.tabs.ClassicPreset
---@field classic true LazyVim's default tab shapes (thin separators, ▎ indicator), styled
---@field strip? string palette colour of the bar (default mantle)
---@field raised? boolean the active tab as a lighter block on the strip instead of a cut-out

---@type table<string, util.tabs.Preset|util.tabs.ClassicPreset>
M.presets = {
  -- LazyVim's shapes on a contained strip: the bar is a solid dark band and
  -- the active tab is cut out of it, showing the (transparent) editor
  -- through, with a blue ▎ on its left
  ["classic"] = { classic = true },
  ["classic-raised"] = { classic = true, raised = true },
  ["classic-crust"] = { classic = true, strip = "crust" },
  -- the hollow-pill family
  ["outline"] = {},
  ["outline-all"] = { all = true },
  ["outline-divided"] = { dividers = true },
  ["outline-solid"] = { solid = true },
  ["outline-roomy"] = { roomy = true },
  ["outline-lavender"] = { color = "lavender" },
}
M.styles = {
  "classic",
  "classic-raised",
  "classic-crust",
  "outline",
  "outline-all",
  "outline-divided",
  "outline-solid",
  "outline-roomy",
  "outline-lavender",
}
M.current = vim.g.tab_style or "classic"

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

---@param p util.tabs.ClassicPreset
---@return table highlights, table options
local function build_classic(p)
  local c = palette()
  local strip = c[p.strip or "mantle"]
  local active_bg = p.raised and c.surface0 or "NONE"
  local hl = {}
  for _, name in ipairs(group_names()) do
    if name:find("_selected$") then
      hl[name] = { bg = active_bg, underline = false, bold = false, italic = false }
    else
      hl[name] = { bg = strip, underline = false, bold = false, italic = false }
    end
  end
  local text = {
    fill = { bg = strip },
    background = { fg = c.overlay1 },
    buffer_visible = { fg = c.subtext0 },
    buffer_selected = { fg = c.text },
    separator = { fg = c.surface1 },
    separator_visible = { fg = c.surface1 },
    separator_selected = { fg = c.surface1 },
    indicator_selected = { fg = c.blue },
    modified = { fg = c.peach },
    modified_visible = { fg = c.peach },
    modified_selected = { fg = c.peach },
    close_button = { fg = c.overlay1 },
    close_button_visible = { fg = c.subtext0 },
    close_button_selected = { fg = c.subtext0 },
    duplicate = { fg = c.overlay1, italic = true },
    duplicate_visible = { fg = c.subtext0, italic = true },
    duplicate_selected = { fg = c.subtext1, italic = true },
    offset_separator = { fg = c.surface1, bg = strip },
    tab = { fg = c.overlay1 },
    tab_selected = { fg = c.text },
    tab_separator = { fg = strip, bg = strip },
    tab_separator_selected = { fg = strip },
    trunc_marker = { fg = c.overlay1 },
  }
  for name, attrs in pairs(text) do
    hl[name] = vim.tbl_extend("force", hl[name] or {}, attrs)
  end
  return hl,
    {
      -- LazyVim / bufferline defaults, spelled out
      indicator = { style = "icon", icon = "▎" },
      separator_style = "thin",
      buffer_close_icon = "󰅖",
      modified_icon = "●",
      show_buffer_close_icons = true,
      hover = { enabled = false },
      numbers = "none",
      name_formatter = nil,
    }
end

---@param p util.tabs.Preset
---@return table highlights, table options
local function build(p)
  if p.classic then
    return build_classic(p)
  end
  local c = palette()
  local border = c[p.color or "blue"]
  local dim = c.surface2
  local hl = {}
  for _, name in ipairs(group_names()) do
    hl[name] = { bg = "NONE", underline = false, bold = false, italic = false }
  end
  local text = {
    background = { fg = c.overlay1 },
    buffer_visible = { fg = c.subtext0 },
    buffer_selected = { fg = c.text },
    separator = { fg = p.dividers and c.surface1 or "NONE" },
    -- caps: left in the indicator slot (active only) or the numbers slot
    -- (every tab); right as the close button, shown on the active tab only
    -- under hover reveal, or on every tab when hover is off
    indicator_selected = { fg = border },
    numbers = { fg = dim },
    numbers_visible = { fg = dim },
    numbers_selected = { fg = border },
    close_button = { fg = dim },
    close_button_visible = { fg = dim },
    close_button_selected = { fg = border },
    -- a modified buffer swaps its right cap for the modified icon: the same
    -- cap, in peach
    modified = { fg = c.peach },
    modified_visible = { fg = c.peach },
    modified_selected = { fg = c.peach },
    duplicate = { fg = c.overlay1, italic = true },
    duplicate_visible = { fg = c.subtext0, italic = true },
    duplicate_selected = { fg = c.subtext1, italic = true },
  }
  if p.solid then
    -- filled pill: the caps are drawn in the pill colour, the inside is it
    for _, name in ipairs(group_names()) do
      if name:find("_selected$") then
        hl[name].bg = border
        hl[name].fg = c.base
      end
    end
    text.buffer_selected = { fg = c.base, bg = border }
    text.indicator_selected = { fg = border, bg = "NONE" }
    text.close_button_selected = { fg = border, bg = "NONE" }
    text.modified_selected = { fg = c.peach, bg = "NONE" }
    text.duplicate_selected = { fg = c.base, bg = border, italic = true }
  end
  for name, attrs in pairs(text) do
    hl[name] = vim.tbl_extend("force", hl[name] or {}, attrs)
  end

  local left, right = LEFT, RIGHT
  if p.solid then
    left, right = LEFT_FILL, RIGHT_FILL
  end
  local options = {
    indicator = p.all and { style = "none" } or { style = "icon", icon = left },
    numbers = p.all and function()
      return left
    end or "none",
    buffer_close_icon = right,
    modified_icon = right,
    show_buffer_close_icons = true,
    hover = { enabled = not p.all, delay = 0, reveal = { "close" } },
    separator_style = { " ", p.dividers and "│" or " " },
    name_formatter = p.roomy and function(buf)
      return " " .. buf.name .. " "
    end or nil,
  }
  return hl, options
end

--- Apply a preset on top of the spec's bufferline opts (LazyVim's merged
--- with ours) and re-run setup so it takes effect immediately.
---@param style? string
function M.apply(style)
  style = style or M.current
  assert(M.presets[style], "unknown tab style: " .. tostring(style))
  M.current, vim.g.tab_style = style, style
  local plugin = require("lazy.core.config").plugins["bufferline.nvim"]
  local base = require("lazy.core.plugin").values(plugin, "opts", false)
  local highlights, options = build(M.presets[style])
  -- bufferline defines its groups as defaults, which never override groups
  -- that already exist — so a re-setup would change nothing. Clear ours
  -- first (a colorscheme switch does the same for it), and the cache of
  -- per-filetype icon groups derived from them.
  for _, name in ipairs(vim.fn.getcompletion("BufferLine", "highlight")) do
    vim.api.nvim_set_hl(0, name, {})
  end
  pcall(function()
    require("bufferline.highlights").reset_icon_hl_cache()
  end)
  local merged = vim.tbl_deep_extend("force", base, { options = options, highlights = highlights })
  merged.options.name_formatter = options.name_formatter -- deep_extend drops a nil
  require("bufferline").setup(merged)
  vim.cmd.redrawtabline()
end

function M.toggle()
  local i = 1
  for n, style in ipairs(M.styles) do
    if style == M.current then
      i = n % #M.styles + 1
    end
  end
  M.apply(M.styles[i])
  vim.notify("Tab style: " .. M.current, vim.log.levels.INFO, { title = "Tabs" })
end

return M
