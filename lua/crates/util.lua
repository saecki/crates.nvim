local semver = require("crates.semver")
local state = require("crates.state")
local types = require("crates.types")
local Span = types.Span

local M = {}

---@enum FeatureInfo
local FeatureInfo = {
    ENABLED = 1,
    TRANSITIVE = 2,
}
M.FeatureInfo = FeatureInfo

local IS_WIN = vim.api.nvim_call_function("has", { "win32" }) == 1

---@return integer
function M.current_buf()
    return vim.api.nvim_get_current_buf()
end

---@return integer, integer
function M.cursor_pos()
    ---@type integer[]
    local cursor = vim.api.nvim_win_get_cursor(0)
    return cursor[1] - 1, cursor[2]
end

---@return Span
function M.selected_lines()
    local info = vim.api.nvim_get_mode()
    if info.mode:match("[vV]") then
        ---@type integer
        local s = vim.fn.getpos("v")[2]
        ---@type integer
        local e = vim.fn.getcurpos()[2]
        return Span.new(s, e)
    else
        local s = vim.api.nvim_buf_get_mark(0, "<")[1]
        local e = vim.api.nvim_buf_get_mark(0, ">")[1]
        return Span.new(s, e)
    end
end

---@param buf integer
---@return table<string, TomlCrate>?
function M.get_buf_crates(buf)
    local cache = state.buf_cache[buf]
    return cache and cache.crates
end

---@param buf integer
---@return table<string, CrateInfo>?
function M.get_buf_info(buf)
    local cache = state.buf_cache[buf]
    return cache and cache.info
end

---@param buf integer
---@return CratesDiagnostic[]?
function M.get_buf_diagnostics(buf)
    local cache = state.buf_cache[buf]
    return cache and cache.diagnostics
end

---@param buf integer
---@param key string
---@return CrateInfo?
function M.get_crate_info(buf, key)
    local info = M.get_buf_info(buf)
    return info and info[key]
end

---@param buf integer
---@param lines Span
---@return table<string,TomlCrate>
function M.get_crates_on_line_span(buf, lines)
    local cache = state.buf_cache[buf]
    local crates = cache and cache.crates
    if not crates then
        return {}
    end

    ---@type table<string,TomlCrate>
    local line_crates = {}
    for k, c in pairs(crates) do
        if lines:contains(c.lines.s) or c.lines:contains(lines.s) then
            line_crates[k] = c
        end
    end

    return line_crates
end

---@param buf integer
---@param line integer?
---@return string?
---@return TomlCrate?
function M.get_crate_on_line(buf, line)
    line = line or M.cursor_pos()
    local cache = state.buf_cache[buf]
    local crates = cache and cache.crates
    if not crates then
        return nil
    end

    for k, c in pairs(crates) do
        if c.lines:contains(line) then
            return k, c
        end
    end
end

---@param versions ApiVersion[]?
---@param reqs Requirement[]?
---@return ApiVersion?
---@return ApiVersion?
---@return ApiVersion?
function M.get_newest(versions, reqs)
    if not versions or not next(versions) then
        return nil
    end

    local allow_pre = reqs and semver.allows_pre(reqs) or false

    ---@type ApiVersion?, ApiVersion?, ApiVersion?
    local newest_yanked, newest_pre, newest

    for _, v in ipairs(versions) do
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
---@param features ApiFeatures
---@return table<string,FeatureInfo>
function M.features_info(crate, features)
    ---@type table<string,FeatureInfo>
    local info = {}

    ---@param f ApiFeature
    local function update_transitive(f)
        for _, m in ipairs(f.members) do
            if not info[m] then
                info[m] = FeatureInfo.TRANSITIVE
                local tf = features:get_feat(m)
                if tf then
                    update_transitive(tf)
                end
            end
        end
    end

    if not crate.def or crate.def.enabled then
        info["default"] = FeatureInfo.ENABLED
        local api_feat = features.list[1]
        update_transitive(api_feat)
    end

    local crate_features = crate.feat
    if not crate_features then
        return info
    end

    for _, crate_feat in ipairs(crate_features.items) do
        local api_feat = features:get_feat(crate_feat.name)
        if api_feat then
            info[api_feat.name] = FeatureInfo.ENABLED
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
    return "https://docs.rs/" .. name
end

---@param name string
---@return string
function M.crates_io_url(name)
    return "https://crates.io/crates/" .. name
end

---@param name string
---@return string
function M.lib_rs_url(name)
    return "https://lib.rs/crates/" .. name
end

---@param url string
function M.open_url(url)
    local _cmd, err = vim.ui.open(url)
    if err then
        M.notify(vim.log.levels.ERROR, "Couldn't open url: %s", err)
    end
end

return M
