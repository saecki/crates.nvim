local M = {Range = {}, }






local Range = M.Range

function Range.new(s, e)
   return setmetatable({ s = s, e = e }, { __index = Range })
end

function Range.pos(p)
   return Range.new(p, p + 1)
end

function Range:contains(pos)
   return self.s <= pos and pos < self.e
end


function Range:moved(s, e)
   return Range.new(self.s + s, self.e + e)
end

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
