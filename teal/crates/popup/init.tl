local record M
    record LineCrateInfo
        pref: Type
        crate: Crate
        versions: {Version}
        newest: Version|nil
        feature: Feature|nil
    end
end

local LineCrateInfo = M.LineCrateInfo
local popup = require("crates.popup.common")
local Type = popup.Type
local popup_deps = require("crates.popup.dependencies")
local popup_feat = require("crates.popup.features")
local popup_vers = require("crates.popup.versions")
local state = require("crates.state")
local toml = require("crates.toml")
local Crate = toml.Crate
local types = require("crates.types")
local Feature = types.Feature
local Range = types.Range
local Version = types.Version
local util = require("crates.util")

local function line_crate_info(): LineCrateInfo
    local pos = vim.api.nvim_win_get_cursor(0)
    local line = pos[1] as integer - 1
    local col = pos[2] as integer

    local crates = util.get_lines_crates(Range.new(line, line + 1))
    if not crates or not crates[1] or not crates[1].versions then
        return nil
    end
    local crate = crates[1].crate
    local versions = crates[1].versions

    local avoid_pre = state.cfg.avoid_prerelease and not crate:vers_is_pre()
    local newest = util.get_newest(versions, avoid_pre, crate:vers_reqs()) as Version

    local info: LineCrateInfo = {
        crate = crate,
        versions = versions,
        newest = newest,
    }

    local function versions_info()
        info.pref = "versions"
    end

    local function features_info()
        for _,cf in ipairs(crate.feat.items) do
            if cf.decl_col:contains(col - crate.feat.col.s) then
                info.feature = newest.features:get_feat(cf.name)
                break
            end
        end

        if info.feature then
            info.pref = "feature_details"
        else
            info.pref = "features"
        end
    end

    local function default_features_info()
        info.feature = newest.features:get_feat("default") or {
            name = "default",
            members = {},
        }
        info.pref = "feature_details"
    end

    if crate.syntax == "plain" then
        versions_info()
    elseif crate.syntax == "table" then
        if crate.feat and line == crate.feat.line then
            features_info()
        elseif crate.def and line == crate.def.line then
            default_features_info()
        else
            versions_info()
        end
    elseif crate.syntax == "inline_table" then
        if crate.feat and line == crate.feat.line and crate.feat.decl_col:contains(col) then
            features_info()
        elseif crate.def and line == crate.def.line and crate.def.decl_col:contains(col) then
            default_features_info()
        else
            versions_info()
        end
    end

    return info
end

function M.show()
    if popup.win and vim.api.nvim_win_is_valid(popup.win) then
        popup.focus()
        return
    end

    local info = line_crate_info()
    if not info then return end

    if info.pref == "versions" then
        popup_vers.open(info.crate, info.versions)
    elseif info.pref == "features" then
        popup_feat.open(info.crate, info.newest, {})
    elseif info.pref == "feature_details" then
        popup_feat.open_details(info.crate, info.newest, info.feature, {})
    elseif info.pref == "dependencies" then
        popup_deps.open(info.crate.name, info.newest, {})
    end
end

function M.focus()
    popup.focus()
end

function M.hide()
    popup.hide()
end

function M.show_versions()
    if popup.win and vim.api.nvim_win_is_valid(popup.win) then
        if popup.type == "versions" then
            popup.focus()
            return
        else
            popup.hide()
        end
    end

    local info = line_crate_info()
    if not info then return end

    popup_vers.open(info.crate, info.versions)
end

function M.show_features()
    if popup.win and vim.api.nvim_win_is_valid(popup.win) then
        if popup.type == "features" then
            popup.focus()
            return
        else
            popup.hide()
        end
    end

    local info = line_crate_info()
    if not info then return end

    if info.pref == "features" then
        popup_feat.open(info.crate, info.newest, {})
    elseif info.pref == "feature_details" then
        popup_feat.open_details(info.crate, info.newest, info.feature, {})
    elseif info.newest then
        popup_feat.open(info.crate, info.newest, {})
    end
end

function M.show_dependencies()
    if popup.win and vim.api.nvim_win_is_valid(popup.win) then
        if popup.type == "dependencies" then
            popup.focus()
            return
        else
            popup.hide()
        end
    end

    local info = line_crate_info()
    if not info then return end

    popup_deps.open(info.crate.name, info.newest, {})
end

return M
