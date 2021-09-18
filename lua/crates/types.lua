---@class Range
---@field s integer -- 0-indexed inclusive
---@field e integer -- 0-indexed exclusive
---@field contains fun(self:Range, pos:integer): boolean

local M = {}

M.Range = {}
local Range = M.Range

---@param s integer
---@param e integer
---@return Range
function Range.new(s, e)
    return setmetatable({ s = s, e = e }, { __index = Range})
end

---@param self Range
---@param pos integer
---@return boolean
function Range:contains(pos)
    return self.s <= pos and pos <  self.e
end

return M
