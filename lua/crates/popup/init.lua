local popup = require("crates.popup.common")
local popup_crate = require("crates.popup.crate")
local popup_deps = require("crates.popup.dependencies")
local popup_feat = require("crates.popup.features")
local popup_vers = require("crates.popup.versions")
local state = require("crates.state")
local toml = require("crates.toml")
local TomlCrateSyntax = toml.TomlCrateSyntax
local types = require("crates.types")
local Span = types.Span
local util = require("crates.util")

local M = {}

---@class LineCrateInfo
---@field pref PopupType
---@field crate TomlCrate
---@field versions ApiVersion[]
---@field newest ApiVersion|nil
---@field feature ApiFeature|nil

---@return LineCrateInfo|nil
local function line_crate_info()
    local buf = util.current_buf()
    local line, col = util.cursor_pos()

    local crates = util.get_line_crates(buf, Span.new(line, line + 1))
    local _,crate = next(crates)
    if not crate then
        return
    end

    local api_crate = state.api_cache[crate:package()]
    if not api_crate then
        return
    end

    local m, p, y = util.get_newest(api_crate.versions, crate:vers_reqs())
    local newest = m or p or y
    -- crates cannot be published if no dependencies match the requirements
    ---@cast newest -nil

    ---@type LineCrateInfo
    local info = {
        crate = crate,
        versions = api_crate.versions,
        newest = newest,
    }

    local function crate_info()
        info.pref = popup.Type.CRATE
    end

    local function versions_info()
        info.pref = popup.Type.VERSIONS
    end

    local function features_info()
        for _,cf in ipairs(crate.feat.items) do
            if cf.decl_col:contains(col - crate.feat.col.s) then
                info.feature = newest.features:get_feat(cf.name)
                break
            end
        end

        if info.feature then
            info.pref = popup.Type.FEATURE_DETAILS
        else
            info.pref = popup.Type.FEATURES
        end
    end

    local function default_features_info()
        info.feature = newest.features.list[1]
        info.pref = popup.Type.FEATURE_DETAILS
    end

    if crate.syntax == TomlCrateSyntax.PLAIN then
        if crate.vers.col:moved(-1, 1):contains(col) then
            versions_info()
        else
            crate_info()
        end
    elseif crate.syntax == TomlCrateSyntax.TABLE then
        if crate.vers and line == crate.vers.line then
            versions_info()
        elseif crate.feat and line == crate.feat.line then
            features_info()
        elseif crate.def and line == crate.def.line then
            default_features_info()
        else
            crate_info()
        end
    elseif crate.syntax == TomlCrateSyntax.INLINE_TABLE then
        if crate.vers and crate.vers.decl_col:contains(col) then
            versions_info()
        elseif crate.feat and crate.feat.decl_col:contains(col) then
            features_info()
        elseif crate.def and  crate.def.decl_col:contains(col) then
            default_features_info()
        else
            crate_info()
        end
    end

    return info
end

---@return boolean
function M.available()
    return line_crate_info() ~= nil
end

function M.show()
    if popup.win and vim.api.nvim_win_is_valid(popup.win) then
        popup.focus()
        return
    end

    local info = line_crate_info()
    if not info then return end

    if info.pref == popup.Type.CRATE then
        local crate = state.api_cache[info.crate:package()]
        if crate then
            popup_crate.open(crate, {})
        end
    elseif info.pref == popup.Type.VERSIONS then
        popup_vers.open(info.crate, info.versions, {})
    elseif info.pref == popup.Type.FEATURES then
        popup_feat.open(info.crate, info.newest, {})
    elseif info.pref == popup.Type.FEATURE_DETAILS then
        popup_feat.open_details(info.crate, info.newest, info.feature, {})
    elseif info.pref == popup.Type.DEPENDENCIES then
        popup_deps.open(info.crate:package(), info.newest, {})
    end
end

function M.focus()
    popup.focus()
end

function M.hide()
    popup.hide()
end

function M.show_crate()
    if popup.win and vim.api.nvim_win_is_valid(popup.win) then
        if popup.type == popup.Type.CRATE then
            popup.focus()
            return
        else
            popup.hide()
        end
    end

    local info = line_crate_info()
    if not info then return end

    local crate = state.api_cache[info.crate:package()]
    if crate then
        popup_crate.open(crate, {})
    end
end

function M.show_versions()
    if popup.win and vim.api.nvim_win_is_valid(popup.win) then
        if popup.type == popup.Type.VERSIONS then
            popup.focus()
            return
        else
            popup.hide()
        end
    end

    local info = line_crate_info()
    if not info then return end

    popup_vers.open(info.crate, info.versions, {})
end

function M.show_features()
    if popup.win and vim.api.nvim_win_is_valid(popup.win) then
        if popup.type == popup.Type.FEATURES then
            popup.focus()
            return
        else
            popup.hide()
        end
    end

    local info = line_crate_info()
    if not info then return end

    if info.pref == popup.Type.FEATURES then
        popup_feat.open(info.crate, info.newest, {})
    elseif info.pref == popup.Type.FEATURE_DETAILS then
        popup_feat.open_details(info.crate, info.newest, info.feature, {})
    elseif info.newest then
        popup_feat.open(info.crate, info.newest, {})
    end
end

function M.show_dependencies()
    if popup.win and vim.api.nvim_win_is_valid(popup.win) then
        if popup.type == popup.Type.DEPENDENCIES then
            popup.focus()
            return
        else
            popup.hide()
        end
    end

    local info = line_crate_info()
    if not info then return end

    popup_deps.open(info.crate:package(), info.newest, {})
end

return M
