local record M
    record CrateVersions
        crate: Crate
        versions: {Version}
    end

    record FeatureInfo
        enabled: boolean
        transitive: boolean
    end
end

local CrateVersions = M.CrateVersions
local FeatureInfo = M.FeatureInfo
local core = require('crates.core')
local semver = require('crates.semver')
local SemVer = semver.SemVer
local Requirement = semver.Requirement
local api = require('crates.api')
local Version = api.Version
local Features = api.Features
local Feature = api.Feature
local toml = require('crates.toml')
local Crate = toml.Crate
local CrateFeature = toml.CrateFeature
local Range = require('crates.types').Range

function M.current_buf(): integer
    return vim.api.nvim_get_current_buf() as integer
end

function M.get_lines_crates(lines: Range): {CrateVersions}
    local crate_versions = {}

    local cur_buf = M.current_buf()
    local crates = core.crate_cache[cur_buf]
    if crates then
        for _,c in pairs(crates) do
            if lines:contains(c.lines.s) or c.lines:contains(lines.s) then
                table.insert(crate_versions, {
                    crate = c,
                    versions = core.vers_cache[c.name]
                })
            end
        end
    end

    return crate_versions
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
                if not avoid_pre or avoid_pre and not v.parsed.suffix then
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

function M.is_feat_enabled(crate: Crate, feature: Feature): boolean
    local enabled = crate:get_feat(feature.name) ~= nil
    if feature.name == "default" then
        return enabled or crate.def ~= false
    else
        return enabled
    end
end

function M.features_info(crate: Crate, features: Features): {string:FeatureInfo}
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

function M.set_version(buf: integer, crate: Crate, text: string)
    if not crate.req_text then return end

    local t = text
    if not crate.req_quote.e then
        t = text .. crate.req_quote.s
    end
    vim.api.nvim_buf_set_text(
        buf,
        crate.req_line,
        crate.req_col.s,
        crate.req_line,
        crate.req_col.e,
        { t }
    )
end

local function replace_existing(r: Requirement, version: SemVer): SemVer
    if version.suffix then
        return version
    else
        return SemVer.new {
            major = version.major,
            minor = r.vers.minor and version.minor or nil,
            patch = r.vers.patch and version.patch or nil,
        }
    end
end

function M.set_version_smart(buf: integer, crate: Crate, version: SemVer)
    if #crate.reqs == 0 then
        M.set_version(buf, crate, version:display())
        return
    end

    local pos = 1
    local text = ""
    for _,r in ipairs(crate.reqs) do
        if r.cond == "wl" then
            if version.suffix then
                text = text .. string.sub(crate.req_text, pos, r.vers_col.s) .. version:display()
            else
                local v = SemVer.new {
                    major = r.vers.major and version.major or nil,
                    minor = r.vers.minor and version.minor or nil,
                }
                local before = string.sub(crate.req_text, pos, r.vers_col.s)
                local after = string.sub(crate.req_text, r.vers_col.e + 1, r.cond_col.e)
                text = text .. before .. v:display() .. after
            end
        elseif r.cond == "tl" then
            local v = replace_existing(r, version)
            text = text .. string.sub(crate.req_text, pos, r.vers_col.s) .. v:display()
        elseif r.cond == "cr" then
            local v = replace_existing(r, version)
            text = text .. string.sub(crate.req_text, pos, r.vers_col.s) .. v:display()
        elseif r.cond == "bl" then
            local v = replace_existing(r, version)
            text = text .. string.sub(crate.req_text, pos, r.vers_col.s) .. v:display()
        elseif r.cond == "lt" and not semver.matches_requirement(version, r) then
            local v = SemVer.new {
                major = version.major,
                minor = r.vers.minor and version.minor or nil,
                patch = r.vers.patch and version.patch or nil,
            }

            if v.patch then
                v.patch = v.patch + 1
            elseif v.minor then
                v.minor = v.minor + 1
            elseif v.major then
                v.major = v.major + 1
            end

            text = text .. string.sub(crate.req_text, pos, r.vers_col.s) .. v:display()
        elseif r.cond == "le" and not semver.matches_requirement(version, r) then
            local v: SemVer

            if version.suffix then
                v = version
            else
                v =  SemVer.new { major = version.major }
                if r.vers.minor or version.minor and version.minor > 0 then
                    v.minor = version.minor
                end
                if r.vers.patch or version.patch and version.patch > 0 then
                    v.minor = version.minor
                    v.patch = version.patch
                end
            end

            text = text .. string.sub(crate.req_text, pos, r.vers_col.s) .. v:display()
        elseif r.cond == "gt" then
            local v = SemVer.new {
                major = r.vers.major and version.major or nil,
                minor = r.vers.minor and version.minor or nil,
                patch = r.vers.patch and version.patch or nil,
            }

            if v.patch then
                v.patch = v.patch - 1
                if v.patch < 0 then
                    v.patch = 0
                    v.minor = v.minor - 1
                end
            elseif v.minor then
                v.minor = v.minor - 1
                if v.minor < 0 then
                    v.minor = 0
                    v.major = v.major - 1
                end
            elseif v.major then
                v.major = v.major - 1
                if v.major < 0 then
                    v.major = 0
                end
            end

            text = text .. string.sub(crate.req_text, pos, r.vers_col.s) .. v:display()
        elseif r.cond == "ge" then
            local v = replace_existing(r, version)
            text = text .. string.sub(crate.req_text, pos, r.vers_col.s) .. v:display()
        else
            text = text .. string.sub(crate.req_text, pos, r.vers_col.e)
        end

        pos = math.max(r.cond_col.e + 1, r.vers_col.e + 1)
    end
    text = text .. string.sub(crate.req_text, pos)

    M.set_version(buf, crate, text)
end

function M.upgrade_crates(lines: Range, smart: boolean)
    local crates = M.get_lines_crates(lines)

    if smart == nil then
        smart = core.cfg.smart_insert
    end

    for _,c in ipairs(crates) do
        local crate = c.crate
        local versions = c.versions

        local avoid_pre = core.cfg.avoid_prerelease and not crate.req_has_suffix
        local newest, newest_pre, newest_yanked = M.get_newest(versions, avoid_pre, nil)
        newest = newest or newest_pre or newest_yanked

        if newest then
            if smart then
                M.set_version_smart(0, crate, newest.parsed)
            else
                M.set_version(0, crate, newest.num)
            end
        end
    end
end

function M.update_crates(lines: Range, smart: boolean)
    local crates = M.get_lines_crates(lines)

    if smart == nil then
        smart = core.cfg.smart_insert
    end

    for _,c in ipairs(crates) do
        local crate = c.crate
        local versions = c.versions

        local avoid_pre = core.cfg.avoid_prerelease and not crate.req_has_suffix
        local match, match_pre, match_yanked = M.get_newest(versions, avoid_pre, crate.reqs)
        match = match or match_pre or match_yanked

        if match then
            if smart then
                M.set_version_smart(0, crate, match.parsed)
            else
                M.set_version(0, crate, match.num)
            end
        end
    end
end

function M.enable_feature(buf: integer, crate: Crate, feature: Feature): Range
    local t = '"' .. feature.name .. '"'
    if not crate.feat_text then
        if crate.syntax == "table" then
            local line = math.max(crate.req_line or 0, crate.def_line or 0) + 1
            vim.api.nvim_buf_set_lines(
                buf,
                line,
                line,
                false,
                { "features = [" .. t .."]" }
            )
            return Range.pos(line)
        elseif crate.syntax == "plain" then
            t = ", features = [" .. t .. "] }"
            local col = crate.req_col.e
            if crate.req_quote.e then
                col = col + 1
            else
                t = crate.req_quote.s .. t
            end
            vim.api.nvim_buf_set_text(
                buf,
                crate.req_line,
                col,
                crate.req_line,
                col,
                { t }
            )

            vim.api.nvim_buf_set_text(
                buf,
                crate.req_line,
                crate.req_col.s - 1,
                crate.req_line,
                crate.req_col.s - 1,
                { "{ version = " }
            )
            return Range.pos(crate.req_line)
        elseif crate.syntax == "inline_table" then
            local line = crate.lines.s
            local req_col_end = 0
            if crate.req_text then
                req_col_end = crate.req_col.e
                if crate.req_quote.e then
                    req_col_end = req_col_end + 1
                end
            end
            local def_col_end = 0
            if crate.def_text then
                def_col_end = crate.def_col.e
            end
            local col = math.max(req_col_end, def_col_end)
            vim.api.nvim_buf_set_text(
                buf,
                line,
                col,
                line,
                col,
                { ", features = [" .. t .. "]" }
            )
            return Range.pos(line)
        end
    else
        local last_feat = crate.feats[#crate.feats]
        if last_feat and not last_feat.comma then
            t = ", " .. t
        end

        vim.api.nvim_buf_set_text(
            buf,
            crate.feat_line,
            crate.feat_col.e,
            crate.feat_line,
            crate.feat_col.e,
            { t }
        )
        return Range.pos(crate.feat_line)
    end
end

function M.disable_feature(buf: integer, crate: Crate, feature: CrateFeature): Range
    local _, index = crate:get_feat(feature.name)

    local col_start = feature.decl_col.s
    local col_end = feature.decl_col.e
    if index == 1 then
        if #crate.feats > 1 then
            col_end = crate.feats[2].col.s - 1
        elseif feature.comma then
            col_end = col_end + 1
        end
    else
        local prev_feature = crate.feats[index - 1]
        col_start = prev_feature.col.e + 1
    end

    vim.api.nvim_buf_set_text(
        buf,
        crate.feat_line,
        crate.feat_col.s + col_start,
        crate.feat_line,
        crate.feat_col.s + col_end,
        { "" }
    )
    return Range.pos(crate.feat_line)
end

function M.enable_def_features(buf: integer, crate: Crate): Range
    vim.api.nvim_buf_set_text(
        buf,
        crate.def_line,
        crate.def_col.s,
        crate.def_line,
        crate.def_col.e,
        { "true" }
    )
    return Range.pos(crate.def_line)
end

function M.disable_def_features(buf: integer, crate: Crate, feature: CrateFeature|nil): Range
    if feature then
        M.disable_feature(buf, crate, feature)
    end

    local line_inserted = false
    if crate.def_text then
        vim.api.nvim_buf_set_text(
            buf,
            crate.def_line,
            crate.def_col.s,
            crate.def_line,
            crate.def_col.e,
            { "false" }
        )
    else
        if crate.syntax == "table" then
            local line = math.max((crate.req_line or 0) + 1, crate.feat_line or 0)
            vim.api.nvim_buf_set_lines(
                buf,
                line,
                line,
                false,
                { "default_features = false" }
            )
            line_inserted = true
        elseif crate.syntax == "plain" then
            local t = ", default_features = false }"
            local col = crate.req_col.e
            if crate.req_quote.e then
                col = col + 1
            else
                t = crate.req_quote.s .. t
            end
            local line = crate.req_line
            vim.api.nvim_buf_set_text(
                buf,
                line,
                col,
                line,
                col,
                { t }
            )

            vim.api.nvim_buf_set_text(
                buf,
                line,
                crate.req_col.s - 1,
                line,
                crate.req_col.s - 1,
                { "{ version = " }
            )
        elseif crate.syntax == "inline_table" then
            local line = crate.lines.s
            if crate.req_text then
                local col = crate.req_col.e
                if crate.req_quote.e then
                    col = col + 1
                end
                vim.api.nvim_buf_set_text(
                    buf, line, col, line, col,
                    { ", default_features = false" }
                )
            elseif crate.feat_text then
                local col = crate.feat_decl_col.s
                vim.api.nvim_buf_set_text(
                    buf, line, col, line, col,
                    { " default_features = false," }
                )
            end
        end
    end

    if line_inserted then
        return crate.lines:moved(0, 1)
    else
        return crate.lines
    end
end

return M
