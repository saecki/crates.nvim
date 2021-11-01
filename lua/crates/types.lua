---@class Range
---@field s integer -- 0-indexed inclusive
---@field e integer -- 0-indexed exclusive

local M = {}

---@type Range
M.Range = {}
local Range = M.Range

---@param s integer
---@param e integer
---@return Range
function Range.new(s, e)
    return setmetatable({ s = s, e = e }, { __index = Range })
end

---@param p integer
---@return Range
function Range.pos(p)
    return Range.new(p, p + 1)
end

---@param self Range
---@param pos integer
---@return boolean
function Range:contains(pos)
    return self.s <= pos and pos <  self.e
end

-- Create a new range with moved start and end bounds
---@param self Range
---@param s integer
---@param e integer
---@return Range
function Range:moved(s, e)
    return Range.new(self.s + s, self.e + e)
end

---@param self Range
---@return fun(): integer
function Range:iter()
    local i = self.s
    return function()
        if i >= self.e then
            return nil
        end

        local val = i
        i = i + 1
        return val
    end
end

return M
