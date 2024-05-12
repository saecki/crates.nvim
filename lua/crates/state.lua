---@class State
---@field cfg Config
---@field api_cache table<string,ApiCrate>
---@field buf_cache table<integer,BufCache>
---@field search_cache SearchCache
---@field visible boolean
local State = {
    api_cache = {},
    buf_cache = {},
    search_cache = {
        results = {},
        searches = {},
    },
    visible = true,
}

---@class BufCache
---@field crates table<string,TomlCrate>
---@field info table<string,CrateInfo>
---@field diagnostics CratesDiagnostic[]
---@field working_crates WorkingCrate[]

---@class SearchCache
---@field searches table<string, string[]>
---@field results table<string, ApiCrateSummary>

return State
