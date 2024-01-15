local semver = require("crates.semver")
local state = require("crates.state")

local M = {}

---@enum FeatureInfo
M.FeatureInfo = {
    ENABLED = 1,
    TRANSITIVE = 2,
}

local IS_WIN = vim.api.nvim_call_function("has", { "win32" }) == 1

---@return integer
function M.current_buf()
    return vim.api.nvim_get_current_buf()
end

---@return integer, integer
function M.cursor_pos()
    ---@type integer[2]
    local cursor = vim.api.nvim_win_get_cursor(0)
    return cursor[1] - 1, cursor[2]
end

---@param buf integer
---@return table<string, TomlCrate>|nil
function M.get_buf_crates(buf)
    local cache = state.buf_cache[buf]
    return cache and cache.crates
end

---@param buf integer
---@return table<string, CrateInfo>|nil
function M.get_buf_info(buf)
    local cache = state.buf_cache[buf]
    return cache and cache.info
end

---@param buf integer
---@return CratesDiagnostic[]|nil
function M.get_buf_diagnostics(buf)
    local cache = state.buf_cache[buf]
    return cache and cache.diagnostics
end

---@param buf integer
---@param key string
---@return CrateInfo|nil
function M.get_crate_info(buf, key)
    local info = M.get_buf_info(buf)
    return info and info[key]
end

---@param buf integer
---@param lines Span
---@return table<string,TomlCrate>
function M.get_line_crates(buf, lines)
    local cache = state.buf_cache[buf]
    local crates = cache and cache.crates
    if not crates then
        return {}
    end

    ---@type table<string,TomlCrate>
    local line_crates = {}
    for k,c in pairs(crates) do
        if lines:contains(c.lines.s) or c.lines:contains(lines.s) then
            line_crates[k] = c
        end
    end

    return line_crates
end

---@param versions ApiVersion[]|nil
---@param reqs Requirement[]|nil
---@return ApiVersion|nil
---@return ApiVersion|nil
---@return ApiVersion|nil
function M.get_newest(versions, reqs)
    if not versions or not next(versions) then
        return nil
    end

    local allow_pre = reqs and semver.allows_pre(reqs) or false

    ---@type ApiVersion|nil, ApiVersion|nil, ApiVersion|nil
    local newest_yanked, newest_pre, newest

    for _,v in ipairs(versions) do
        if not reqs or semver.matches_requirements(v.parsed, reqs) then
            if not v.yanked then
                if allow_pre or not v.parsed.pre then
                    newest = v
                    break
                else
                    newest_pre = newest_pre or v
                end
            else
                newest_yanked = newest_yanked or v
            end
        end
    end

    return newest, newest_pre, newest_yanked
end

---@param crate TomlCrate
---@param feature ApiFeature
---@return boolean
function M.is_feat_enabled(crate, feature)
    local enabled = crate:get_feat(feature.name) ~= nil
    if feature.name == "default" then
        return enabled or crate:is_def_enabled()
    else
        return enabled
    end
end

---@param crate TomlCrate
---@param features ApiFeatures
---@return table<string,FeatureInfo>
function M.features_info(crate, features)
    ---@type table<string,FeatureInfo>
    local info = {}

    ---@param f ApiFeature
    local function update_transitive(f)
        for _,m in ipairs(f.members) do
            local tf = features:get_feat(m)
            if tf then
                local i = info[m]
                if not i then
                    info[m] = M.FeatureInfo.TRANSITIVE
                    update_transitive(tf)
                end
            end
        end
    end

    if not crate.def or crate.def.enabled then
        info["default"] = M.FeatureInfo.ENABLED
        local api_feat = features.list[1]
        update_transitive(api_feat)
    end

    local crate_features = crate.feat
    if not crate_features then
        return info
    end

    for _,crate_feat in ipairs(crate_features.items) do
        local api_feat = features:get_feat(crate_feat.name)
        if api_feat then
            info[api_feat.name] = M.FeatureInfo.ENABLED
            update_transitive(api_feat)
        end
    end

    return info
end

---@param name string
---@return boolean
function M.lualib_installed(name)
    local ok = pcall(require, name)
    return ok
end

---comment
---@param name string
---@return boolean
function M.binary_installed(name)
    if IS_WIN then
        name = name .. ".exe"
    end

    return vim.fn.executable(name) == 1
end

---comment
---@param severity integer
---@param s string
---@param ... any
function M.notify(severity, s, ...)
    vim.notify(s:format(...), severity, { title = state.cfg.notification_title })
end

---@param name string
---@return string
function M.docs_rs_url(name)
    return "https://docs.rs/"..name
end

---@param name string
---@return string
function M.crates_io_url(name)
    return "https://crates.io/crates/"..name
end

---@param url string
function M.open_url(url)
    for _, prg in ipairs(state.cfg.open_programs) do
        if M.binary_installed(prg) then
            vim.cmd(string.format("silent !%s %s", prg, url))
            return
        end
    end

    M.notify(vim.log.levels.WARN, "Couldn't open url")
end

---@param name string
---@return string
function M.format_title(name)
    return name:sub(1, 1):upper() .. name:gsub("_", " "):sub(2)
end

return M
