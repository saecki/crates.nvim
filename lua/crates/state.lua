---@class State
---@field cfg Config
---@field _cfg Config
---@field api_cache table<string,ApiCrate>
---@field buf_cache table<integer,BufCache>
---@field local_config table<integer, crates.UserConfig>
---@field visible boolean
local State = {
    api_cache = {},
    buf_cache = {},
    visible = true,
    local_config = {},
}

---@param config Config
function State:set_cfg(config)
    self._cfg = config
    self.cfg = setmetatable({}, {
        __index = function (_, key)
            ---@type integer
            local buf = vim.api.nvim_get_current_buf()
            local cfg = self.local_config[buf]
            if cfg and cfg[key] then
                return cfg[key]
            end
            return self._cfg[key]
        end
    })
end

---@class BufCache
---@field crates table<string,TomlCrate>
---@field info table<string,CrateInfo>
---@field diagnostics CratesDiagnostic[]

State.api_cache = {}
State.buf_cache = {}
State.visible = true

return State
