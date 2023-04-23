local record M
    record FeatureInfo
        enabled: boolean
        transitive: boolean
    end
end

local FeatureInfo = M.FeatureInfo
local semver = require("crates.semver")
local state = require("crates.state")
local toml = require("crates.toml")
local types = require("crates.types")
local Diagnostic = types.Diagnostic
local CrateInfo = types.CrateInfo
local Feature = types.Feature
local Features = types.Features
local Range = types.Range
local Requirement = types.Requirement
local Version = types.Version

local IS_WIN = vim.api.nvim_call_function("has", { "win32" }) == 1

function M.current_buf(): integer
    return vim.api.nvim_get_current_buf() as integer
end

function M.cursor_pos(): integer, integer
    local cursor = vim.api.nvim_win_get_cursor(0)
    return cursor[1] - 1, cursor[2]
end

function M.get_buf_crates(buf: integer): {string:toml.Crate}
    local cache = state.buf_cache[buf]
    return cache and cache.crates
end

function M.get_buf_info(buf: integer): {string:CrateInfo}
    local cache = state.buf_cache[buf]
    return cache and cache.info
end

function M.get_buf_diagnostics(buf: integer): {Diagnostic}
    local cache = state.buf_cache[buf]
    return cache and cache.diagnostics
end

function M.get_crate_info(buf: integer, key: string): CrateInfo
    local info = M.get_buf_info(buf)
    return info[key]
end

function M.get_line_crates(buf: integer, lines: Range): {string:toml.Crate}
    local cache = state.buf_cache[buf]
    local crates = cache and cache.crates
    if not crates then
        return {}
    end

    local line_crates = {}
    for k,c in pairs(crates) do
        if lines:contains(c.lines.s) or c.lines:contains(lines.s) then
            line_crates[k] = c
        end
    end

    return line_crates
end

function M.get_newest(versions: {Version}, avoid_pre: boolean, reqs: {Requirement}|nil): Version, Version, Version
    if not versions then
        return nil
    end

    local newest_yanked: Version = nil
    local newest_pre: Version = nil
    local newest: Version = nil

    for _,v in ipairs(versions) do
        if not reqs or semver.matches_requirements(v.parsed, reqs) then
            if not v.yanked then
                if not avoid_pre or avoid_pre and not v.parsed.pre then
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

function M.is_feat_enabled(crate: toml.Crate, feature: Feature): boolean
    local enabled = crate:get_feat(feature.name) ~= nil
    if feature.name == "default" then
        return enabled or crate:is_def_enabled()
    else
        return enabled
    end
end

function M.features_info(crate: toml.Crate, features: Features): {string:FeatureInfo}
    local info: {string:FeatureInfo} = {}

    local function update_transitive(f: Feature)
        for _,m in ipairs(f.members) do
            local tf = features:get_feat(m)
            if tf then
                local i = info[m]
                if i then
                    if not i.transitive then
                        i.transitive = true
                    end
                else
                    info[m] = {
                        enabled = false,
                        transitive = true,
                    }
                    update_transitive(tf)
                end
            end
        end
    end

    for _,f in ipairs(features) do
        local enabled = M.is_feat_enabled(crate, f)
        local i = info[f.name]
        if i then
            i.enabled = enabled
        else
            info[f.name] = {
                enabled = enabled,
                transitive = false,
            }
        end

        if enabled then
            update_transitive(f)
        end
    end

    return info
end

function M.lualib_installed(name: string): boolean
    local ok, _ = pcall(require as function(string): (any), name)
    return ok
end

function M.binary_installed(name: string): boolean
    if IS_WIN then
        name = name .. ".exe"
    end

    return vim.fn.executable(name) == 1
end

function M.notify(severity: integer, s: string, ...:any)
    vim.notify(s:format(...), severity, { title = state.cfg.notification_title })
end

function M.docs_rs_url(name: string): string
    return "https://docs.rs/"..name
end

function M.crates_io_url(name: string): string
    return "https://crates.io/crates/"..name
end

function M.open_url(url: string)
    for _, prg in ipairs(state.cfg.open_programs) do
        if M.binary_installed(prg) then
            vim.cmd(string.format("silent !%s %s", prg, url))
            return
        end
    end

    M.notify(vim.log.levels.WARN, "Couldn't open url")
end

return M
