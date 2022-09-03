local M = {DateTime = {}, }





local DateTime = M.DateTime

function DateTime.new(epoch)
   return setmetatable({ epoch = epoch }, { __index = DateTime })
end

function DateTime.parse_rfc_3339(str)

   local pat = "^([0-9][0-9][0-9][0-9])%-([0-9][0-9])%-([0-9][0-9])" ..
   "T([0-9][0-9]):([0-9][0-9]):([0-9][0-9])%.[0-9]+" ..
   "([%+%-])([0-9][0-9]):([0-9][0-9])$"

   local year, month, day, hour, minute, second, offset, offset_hour, offset_minute = str:match(pat)
   if year then
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

function DateTime:display(format)
   return os.date(format, self.epoch)
end

return M
