local M = {}





local src = require("crates.src")

local function new_uid(map)
   local key
   repeat
      key = math.floor(math.random() * 10000)
   until not map[key]
   return key
end

M.name = "crates"

function M.fn(_, callback)
   if vim.fn.expand("%:t") ~= "Cargo.toml" then
      callback(nil)
      return
   end

   src.complete(callback)
end

function M.setup()
   COQsources = COQsources or {}
   COQsources[new_uid(COQsources)] = M
end

return M
