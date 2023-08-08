local M = {CrateInfo = {}, Diagnostic = {}, Crate = {}, Version = {}, Features = {}, Feature = {}, Dependency = {Vers = {}, }, SemVer = {}, Requirement = {}, Range = {}, }






































































































































local Diagnostic = M.Diagnostic
local Feature = M.Feature
local Features = M.Features
local Range = M.Range
local SemVer = M.SemVer
local time = require("crates.time")
local DateTime = time.DateTime

function Diagnostic.new(obj)
   return setmetatable(obj, { __index = Diagnostic })
end

function Diagnostic:contains(line, col)
   return (self.lnum < line or self.lnum == line and self.col <= col) and
   (self.end_lnum > line or self.end_lnum == line and self.end_col > col)
end


function Features.new(obj)
   return setmetatable(obj, { __index = Features })
end

function Features:get_feat(name)
   for i, f in ipairs(self) do
      if f.name == name then
         return f, i
      end
   end

   return nil, nil
end

function Features:sort()
   table.sort(self, function(a, b)
      if a.name == "default" then
         return true
      elseif b.name == "default" then
         return false
      else
         return a.name < b.name
      end
   end)
end


function SemVer.new(obj)
   return setmetatable(obj, { __index = SemVer })
end

function SemVer:display()
   local text = ""
   if self.major then
      text = text .. self.major
   end

   if self.minor then
      text = text .. "." .. self.minor
   end

   if self.patch then
      text = text .. "." .. self.patch
   end

   if self.pre then
      text = text .. "-" .. self.pre
   end

   if self.meta then
      text = text .. "+" .. self.meta
   end

   return text
end


function Range.new(s, e)
   return setmetatable({ s = s, e = e }, { __index = Range })
end

function Range.pos(p)
   return Range.new(p, p + 1)
end

function Range.empty()
   return Range.new(0, 0)
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
