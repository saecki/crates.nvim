---@class CrateVersions
---@field crate Crate
---@field versions Version[]

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

---@param lines Range
function M.upgrade_crates(lines)
    local crates = M.get_lines_crates(lines)

    for _,c in ipairs(crates) do
        local crate = c.crate
        local versions = c.versions

        local avoid_pre = core.cfg.avoid_prerelease and not crate.req_has_suffix
        local newest, newest_pre, newest_yanked = M.get_newest(versions, avoid_pre, nil)
        newest = newest or newest_pre or newest_yanked

        if newest then
            M.set_version(0, crate, newest.num)
        end
    end
end

---@param lines Range
function M.update_crates(lines)
    local crates = M.get_lines_crates(lines)

    for _,c in ipairs(crates) do
        local crate = c.crate
        local versions = c.versions

        local avoid_pre = core.cfg.avoid_prerelease and not crate.req_has_suffix
        local match, match_pre, match_yanked = M.get_newest(versions, avoid_pre, crate.reqs)
        match = match or match_pre or match_yanked

        if match then
            M.set_version(0, crate, match.num)
        end
    end
end


return M
