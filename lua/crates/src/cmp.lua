local M = {}

local cmp = require("cmp")
local lsp = cmp.lsp
local src = require("crates.src.common")


function M.new()
   return setmetatable({}, { __index = M })
end


function M.get_debug_name()
   return "crates"
end


function M:is_available()
   return vim.fn.expand("%:t") == "Cargo.toml"
end





function M:get_keyword_pattern(_)
   return [[\([^"'\%^<>=~,\s]\)*]]
end


function M:get_trigger_characters(_)
   return { '"', "'", ".", "<", ">", "=", "^", "~", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
end



function M:complete(_, callback)
   src.complete(callback)
end

return M
