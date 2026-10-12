local util = require("util")
local fs = require("fs")

--- Doc comment one
--- Doc comment two
local M = {}

--[[
A block comment
spanning lines
]]
local config = {
  name = "x",
  items = {
    1,
    2,
  },
}

function M.run(a, b)
  if a > b then
    return a
  elseif a == b then
    return 0
  else
    return b
  end
end

local function each(list)
  for i, v in ipairs(list) do
    print(i, v)
  end
  while false do
    break
  end
  repeat
    list = nil
  until true
end

M.handler = function(
  req,
  res
)
  util.call(
    req,
    res
  )
  return fs.read([[
multi
line
]])
end

return M
