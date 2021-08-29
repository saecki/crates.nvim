---@class Core
---@field cfg Config
---@field vers_cache table<string, Version[]>
---@field crate_cache table<integer, table<string, Crate>>
---@field visible boolean

local M = {}

M.cfg = {}
M.vers_cache = {}
M.crate_cache = {}
M.visible = false

return M
