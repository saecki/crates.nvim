---@class State
---@field cfg Config
---@field api_cache table<string,ApiCrate>
---@field buf_cache table<integer,BufCache>
---@field visible boolean
local State = {
    api_cache = {},
    buf_cache = {},
    visible = true,
}

---@class BufCache
---@field crates table<string,TomlCrate>
---@field info table<string,CrateInfo>
---@field diagnostics CratesDiagnostic[]

State.api_cache = {}
State.buf_cache = {}
State.visible = true

return State
