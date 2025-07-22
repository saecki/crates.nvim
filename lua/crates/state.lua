---@param name string
---@return string
local function normalize_crate_name(name)
    local id = name:lower():gsub("-", "_")
    return id
end

local ApiCache = {}

function ApiCache.new()
    return setmetatable({}, ApiCache)
end

function ApiCache:__index(key)
    local val = rawget(self, key)
    if val then
        return val
    end

    local id = normalize_crate_name(key)
    return rawget(self, id)
end

function ApiCache:__newindex(key, value)
    local id = normalize_crate_name(key)
    return rawset(self, id, value)
end

---@class BufCache
---@field crates table<string,TomlCrate>
---@field info table<string,CrateInfo>
---@field diagnostics CratesDiagnostic[]
---@field working_crates WorkingCrate[]

---@class SearchCache
---@field searches table<string, string[]>
---@field results table<string, ApiCrateSummary>

---@class State
---@field cfg Config
---@field buf_cache table<integer,BufCache>
---@field api_cache table<string,ApiCrate>
---@field search_cache SearchCache
---@field visible boolean
local State = {
    buf_cache = {},
    api_cache = ApiCache.new(),
    search_cache = {
        results = {},
        searches = {},
    },
    visible = true,
}

function State:clear_cache()
    self.api_cache = ApiCache.new()
    self.search_cache = {
        results = {},
        searches = {},
    }
end

return State
