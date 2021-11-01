---@class DateTime
---@field epoch integer

local M = {}

local core = require('crates.core')

---@type DateTime
M.DateTime = {}
local DateTime = M.DateTime

---@param epoch integer
---@return DateTime
function DateTime.new(epoch)
    return setmetatable({ epoch = epoch }, { __index = DateTime })
end

---@param str string
---@return DateTime
function DateTime.parse_rfc_3339(str)
    -- lua regex suports no {n} occurences
    local pat = "^([0-9][0-9][0-9][0-9])%-([0-9][0-9])%-([0-9][0-9])" -- date
    .."T([0-9][0-9]):([0-9][0-9]):([0-9][0-9])%.[0-9]+" -- time
    .."([%+%-])([0-9][0-9]):([0-9][0-9])$" -- offset

    local year, month, day, hour, minute, second, offset, offset_hour, offset_minute = str:match(pat)
    if year then
        if offset == "+" then
            hour = hour + offset_hour
            minute = minute + offset_minute
        elseif offset == "-" then
            hour = hour - offset_hour
            minute = minute - offset_minute
        end
        return DateTime.new(os.time {
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = tonumber(hour),
            minute = tonumber(minute),
            second = tonumber(second),
        })
    end

    return nil
end

---@param self DateTime
---@return string
function DateTime:display()
    return os.date(core.cfg.date_format, self.epoch)
end

return M
