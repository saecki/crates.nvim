local record M
    name: string
    fn: function(table, function(src.CompletionList|nil))
end

global COQsources: {integer:any}
local src = require("crates.src")

local function new_uid(map: {integer:any}): integer
    local key: integer
    repeat
        key = math.floor(math.random() * 10000)
    until not map[key]
    return key
end

M.name = "crates"

function M.fn(_: table, callback: function(src.CompletionList|nil))
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
