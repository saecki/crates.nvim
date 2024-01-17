local M = {}

---@class CoqCompletionSource
---@field name string
---@field fn fun(ctx: table, callback: fun(list: CompletionList|nil))

local src = require("crates.src.common")

---comment
---@param map table<integer,any>
---@return integer
local function new_uid(map)
    ---@type integer
    local key
    repeat
        key = math.floor(math.random() * 10000)
    until not map[key]
    return key
end

---@param _ctx table
---@param callback fun(list: CompletionList|nil)
function M.complete(_ctx, callback)
    if vim.fn.expand("%:t") ~= "Cargo.toml" then
        callback(nil)
        return
    end

    src.complete(callback)
end

---@param name string
function M.setup(name)
    COQsources = COQsources or {}
    COQsources[new_uid(COQsources)] = {
        name = name,
        fn = M.complete,
    }
end

return M
