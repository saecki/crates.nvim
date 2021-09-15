---@class Core
---@field cfg Config
---@field vers_cache table<string, Version[]>
---@field crate_cache table<integer, table<string, Crate>>
---@field visible boolean

---@type Core
local M = {
    cfg = {},
    vers_cache = {},
    crate_cache = {},
    visible = false,
}

return M
