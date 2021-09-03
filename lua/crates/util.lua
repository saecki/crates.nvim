---@class CrateVersions
---@field crate Crate
---@field versions Version[]

---@class Range
---@field s integer -- 0-indexed inclusive
---@field e integer -- 0-indexed exclusive

local M = {}

local core = require('crates.core')
local semver = require('crates.semver')

---@return integer
function M.current_buf()
    return vim.api.nvim_get_current_buf()
end

---@param range Range
---@param pos integer
---@return boolean
function M.contains(range, pos)
    return range.s <= pos and range.e > pos
end

---@param lines Range
---@return CrateVersions[]
function M.get_lines_crates(lines)
    local crate_versions = {}

    local cur_buf = M.current_buf()
    local crates = core.crate_cache[cur_buf]
    if crates then
        for _,c in pairs(crates) do
            if M.contains(lines, c.line.s) or M.contains(c.line, lines.s) then
                table.insert(crate_versions, {
                    crate = c,
                    versions = core.vers_cache[c.name]
                })
            end
        end
    end

    return crate_versions
end

---@param versions Version[]
---@param avoid_pre boolean
---@param reqs Requirement[]
---@return Version, Version, Version
function M.get_newest(versions, avoid_pre, reqs)
    if not versions then
        return nil
    end

    local newest_yanked = nil
    local newest_pre = nil
    local newest = nil

    for _,v in ipairs(versions) do
        if not reqs or reqs and semver.matches_requirements(v.parsed, reqs) then
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

---@param buf integer
---@param crate Crate
---@param text string
function M.set_version(buf, crate, text)
    local t = text
    if not crate.quote.e then
        t = text .. crate.quote.s
    end
    vim.api.nvim_buf_set_text(
        buf,
        crate.vers_line,
        crate.col.s,
        crate.vers_line,
        crate.col.e - 1,
        { t }
    )
end

---@param buf integer
---@param crate Crate
---@param version Version
function M.set_version_smart(buf, crate, version)
    local pos = 1
    local text = ""
    for _,r in ipairs(crate.reqs) do
        if r.cond == "wl" then
            local v = semver.semver {
                major = r.vers.major and version.parsed.major or nil,
                minor = r.vers.minor and version.parsed.minor or nil,
            }
            text = text .. string.sub(crate.req_text, pos, r.col.s) .. v:display()
        elseif r.cond == "tl" then
            local v = semver.semver {
                major = r.vers.major and version.parsed.major or nil,
                minor = r.vers.minor and version.parsed.minor or nil,
                patch = r.vers.patch and version.parsed.patch or nil,
                suffix = r.vers.suffix and version.parsed.suffix or nil,
            }
            text = text .. string.sub(crate.req_text, pos, r.col.s) .. v:display()
        elseif r.cond == "cr" or r.cond == "bl" then
            local v = semver.semver {
                major = r.vers.major and version.parsed.major or nil,
                minor = r.vers.minor and version.parsed.minor or nil,
                patch = r.vers.patch and version.parsed.patch or nil,
                suffix = r.vers.suffix and version.parsed.suffix or nil,
            }
            text = text .. string.sub(crate.req_text, pos, r.col.s) .. v:display()
        elseif r.cond == "lt" and not semver.matches_requirement(version.parsed, r) then
            local v = semver.semver {
                major = r.vers.major and version.parsed.major or nil,
                minor = r.vers.minor and version.parsed.minor or nil,
                patch = r.vers.patch and version.parsed.patch or nil,
            }
            if v.patch then
                v.patch = v.patch + 1
            elseif v.minor then
                v.minor = v.minor + 1
            elseif v.major then
                v.major = v.major + 1
            end
            text = text .. string.sub(crate.req_text, pos, r.col.s) .. v:display()
        elseif r.cond == "le" and not semver.matches_requirement(version.parsed, r) then
            local v = semver.semver {
                major = r.vers.major and version.parsed.major or nil,
                minor = r.vers.minor and version.parsed.minor or nil,
                patch = r.vers.patch and version.parsed.patch or nil,
                suffix = r.vers.suffix and version.parsed.suffix or nil,
            }
            if not v.minor and version.parsed.minor and version.parsed.minor > 0 then
                v.minor = version.parsed.minor
            end
            if not v.patch and version.parsed.patch and version.parsed.patch > 0 then
                v.minor = version.parsed.minor
                v.patch = version.parsed.patch
            end
            if not v.suffix and version.parsed.suffix then
                v.suffix = version.parsed.suffix
            end
            text = text .. string.sub(crate.req_text, pos, r.col.s) .. v:display()
        elseif r.cond == "gt" then
            local v = semver.semver {
                major = r.vers.major and version.parsed.major or nil,
                minor = r.vers.minor and version.parsed.minor or nil,
                patch = r.vers.patch and version.parsed.patch or nil,
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
                if v.minor < 0 then
                    v.major = 0
                end
            end
            text = text .. string.sub(crate.req_text, pos, r.col.s) .. v:display()
        elseif r.cond == "ge" then
            local v = semver.semver {
                major = r.vers.major and version.parsed.major or nil,
                minor = r.vers.minor and version.parsed.minor or nil,
                patch = r.vers.patch and version.parsed.patch or nil,
                suffix = r.vers.suffix and version.parsed.suffix or nil,
            }
            text = text .. string.sub(crate.req_text, pos, r.col.s) .. v:display()
        else
            text = text .. string.sub(crate.req_text, pos, r.col.e)
        end

        pos = r.col.e + 1
    end
    text = text .. string.sub(crate.req_text, pos)

    M.set_version(buf, crate, text)
end

---@param lines Range
---@param smart boolean
function M.upgrade_crates(lines, smart)
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
                M.set_version_smart(0, crate, newest)
            else
                M.set_version(0, crate, newest.num)
            end
        end
    end
end

---@param lines Range
---@param smart boolean
function M.update_crates(lines, smart)
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
                M.set_version_smart(0, crate, match)
            else
                M.set_version(0, crate, match.num)
            end
        end
    end
end


return M
