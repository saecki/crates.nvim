local record M
    record Range
        s: integer -- 0-indexed inclusive
        e: integer -- 0-indexed exclusive
    end
end

local Range = M.Range

function Range.new(s: integer, e: integer): Range
    return setmetatable({ s = s, e = e }, { __index = Range })
end

function Range.pos(p: integer): Range
    return Range.new(p, p + 1)
end

function Range.empty(): Range
    return Range.new(0, 0)
end

function Range:contains(pos: integer): boolean
    return self.s <= pos and pos <  self.e
end

-- Create a new range with moved start and end bounds
function Range:moved(s: integer, e: integer): Range
    return Range.new(self.s + s, self.e + e)
end

function Range:iter(): function(): integer
    local i = self.s
    return function(): integer
        if i >= self.e then
            return nil
        end

        local val = i
        i = i + 1
        return val
    end
end

return M
