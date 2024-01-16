local M = {}

---@class DateTime
---@field epoch integer
local DateTime = {}
M.DateTime = DateTime

---@param epoch integer
---@return DateTime
function DateTime.new(epoch)
    return setmetatable({ epoch = epoch }, { __index = DateTime })
end

---@param str string
---@return DateTime|nil
function DateTime.parse_rfc_3339(str)
    -- lua regex suports no {n} occurences
    local pat = "^([0-9][0-9][0-9][0-9])%-([0-9][0-9])%-([0-9][0-9])" -- date
        .. "T([0-9][0-9]):([0-9][0-9]):([0-9][0-9])%.[0-9]+" -- time
        .. "([%+%-])([0-9][0-9]):([0-9][0-9])$" -- offset

    local year, month, day, hour, minute, second, offset, offset_hour, offset_minute = str:match(pat)
    if year then
        ---@type integer, integer
        local h, m
        if offset == "+" then
            h = tonumber(hour) + tonumber(offset_hour)
            m = tonumber(minute) + tonumber(offset_minute)
        elseif offset == "-" then
            h = tonumber(hour) - tonumber(offset_hour)
            m = tonumber(minute) - tonumber(offset_minute)
        end
        return DateTime.new(os.time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = h,
            min = m,
            sec = tonumber(second),
        }))
    end

    return nil
end

---@param format string
---@return string
function DateTime:display(format)
    ---@type string
    return os.date(format, self.epoch)
end

return M
