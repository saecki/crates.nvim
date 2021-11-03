local record M
    record DateTime
        epoch: integer
    end
end

local DateTime = M.DateTime

function DateTime.new(epoch: integer): DateTime
    return setmetatable({ epoch = epoch }, { __index = DateTime })
end

function DateTime.parse_rfc_3339(str: string): DateTime
    -- lua regex suports no {n} occurences
    local pat = "^([0-9][0-9][0-9][0-9])%-([0-9][0-9])%-([0-9][0-9])" -- date
    .."T([0-9][0-9]):([0-9][0-9]):([0-9][0-9])%.[0-9]+" -- time
    .."([%+%-])([0-9][0-9]):([0-9][0-9])$" -- offset

    local year, month, day, hour, minute, second, offset, offset_hour, offset_minute = str:match(pat)
    if year then
        local h, m: number, number
        if offset == "+" then
            h = tonumber(hour) + tonumber(offset_hour)
            m = tonumber(minute) + tonumber(offset_minute)
        elseif offset == "-" then
            h = tonumber(hour) - tonumber(offset_hour)
            m = tonumber(minute) - tonumber(offset_minute)
        end
        return DateTime.new(os.time {
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = h,
            minute = m,
            second = tonumber(second),
        })
    end

    return nil
end

function DateTime:display(format: string): string
    return os.date(format, self.epoch)
end

return M
