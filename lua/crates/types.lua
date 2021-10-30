---@class Range
---@field s integer -- 0-indexed inclusive
---@field e integer -- 0-indexed exclusive
---@field contains fun(self:Range, pos:integer): boolean
---@field moved fun(self:Range, s:integer, e:integer): Range

local M = {}

M.Range = {}
local Range = M.Range

---@param s integer
---@param e integer
---@return Range
function Range.new(s, e)
    return setmetatable({ s = s, e = e }, { __index = Range })
end

---@param self Range
---@param pos integer
---@return boolean
function Range:contains(pos)
    return self.s <= pos and pos <  self.e
end

-- Create a new range with moved start and end bounds
---@param s integer
---@param e integer
---@return Range
function Range:moved(s, e)
    return Range.new(self.s + s, self.e + e)
end

return M
