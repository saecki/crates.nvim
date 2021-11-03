local record M
    record Range
        s: number -- 0-indexed inclusive
        e: number -- 0-indexed exclusive
    end
end

local Range = M.Range

function Range.new(s: number, e: number): Range
    return setmetatable({ s = s, e = e }, { __index = Range })
end

function Range.pos(p: number): Range
    return Range.new(p, p + 1)
end

function Range:contains(pos: number): boolean
    return self.s <= pos and pos <  self.e
end

-- Create a new range with moved start and end bounds
function Range:moved(s: number, e: number): Range
    return Range.new(self.s + s, self.e + e)
end

function Range:iter(): function(): number
    local i = self.s
    return function(): number
        if i >= self.e then
            return nil
        end

        local val = i
        i = i + 1
        return val
    end
end

return M
