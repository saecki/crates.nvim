local M = {}





local src = require("crates.src.common")

local function new_uid(map)
   local key
   repeat
      key = math.floor(math.random() * 10000)
   until not map[key]
   return key
end

function M.complete(_, callback)
   if vim.fn.expand("%:t") ~= "Cargo.toml" then
      callback(nil)
      return
   end

   src.complete(callback)
end

function M.setup(name)
   COQsources = COQsources or {}
   COQsources[new_uid(COQsources)] = {
      name = name,
      fn = M.complete,
   }
end

return M
