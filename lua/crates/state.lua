---@class State
---@field cfg Config
---@field _cfg Config
---@field api_cache table<string,ApiCrate>
---@field buf_cache table<integer,BufCache>
---@field visible boolean
local State = {
    api_cache = {},
    buf_cache = {},
    visible = true,
}

---@param config Config
function State:set_cfg(config)
    self._cfg = config
    self.cfg = setmetatable({}, {
        __index = function (_, key)
            ---@type integer
            local buf = vim.api.nvim_get_current_buf()
            local cache = self.buf_cache[buf]
            if cache and cache.local_config and cache.local_config[key] then
                return cache.local_config[key]
            end
            return self._cfg[key]
        end
    })
end

---@class BufCache
---@field crates table<string,TomlCrate>
---@field info table<string,CrateInfo>
---@field diagnostics CratesDiagnostic[]
---@field local_config crates.UserConfig?

State.api_cache = {}
State.buf_cache = {}
State.visible = true

return State
