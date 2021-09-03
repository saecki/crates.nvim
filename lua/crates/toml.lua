---@class Crate
---@field name string
---@field req_text string
---@field reqs Requirement[]
---@field req_has_suffix boolean
---@field vers_line integer -- 0-indexed
---@field syntax string
---@field line Range
---@field col Range
---@field quote Quotes

---@class Quotes
---@field s string
---@field e string

local M = {}

local semver = require('crates.semver')

---@param line string
---@return Crate
function M.parse_crate_dep_section_line(line)
    local qs, vs, req_text, ve, qe = line:match([[^%s*version%s*=%s*(["'])()([^"']*)()(["']?)%s*$]])
    if qs and vs and req_text and ve then
        return {
            req_text = req_text,
            col = { s = vs - 1, e = ve },
            quote = { s = qs, e = qe ~= "" and qe or nil },
            syntax = "section",
        }
    end

    return nil
end

---@param line string
---@return Crate
function M.parse_dep_section_line(line)
    local name, qs, vs, req_text, ve, qe
    -- plain version
    name, qs, vs, req_text, ve, qe = line:match([[^%s*([^%s]+)%s*=%s*(["'])()([^"']*)()(["']?)%s*$]])
    if name and qs and vs and req_text and ve then
        return {
            name = name,
            req_text = req_text,
            col = { s = vs - 1, e = ve },
            quote = { s = qs, e = qe ~= "" and qe or nil },
            syntax = "normal",
        }
    end

    -- version in map
    local pat = [[^%s*([^%s]+)%s*=%s*{.*[,]?%s*version%s*=%s*(["'])()([^"']*)()(["']?)%s*[,]?.*[}]?%s*$]]
    name, qs, vs, req_text, ve, qe = line:match(pat)
    if name and qs and vs and req_text and ve then
        return {
            name = name,
            req_text = req_text,
            col = { s = vs - 1, e = ve },
            quote = { s = qs, e = qe ~= "" and qe or nil },
            syntax = "map",
        }
    end

    return nil
end

---@param buf integer
---@return Crate[]
function M.parse_crates(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    local crates = {}
    local dep_section = false
    local dep_section_start = 0
    local dep_section_crate = nil
    local dep_section_crate_name = nil -- [dependencies.<crate>]

    for i,l in ipairs(lines) do
        local uncommented = l:match("^([^#]*)#.*$")
        if uncommented then
            l = uncommented
        end

        local section = l:match("^%s*%[(.+)%]%s*$")

        if section then
            -- push pending crate
            if dep_section_crate then
                dep_section_crate.line = { s = dep_section_start, e = i - 1 }
                table.insert(crates, dep_section_crate)
            end

            local c = section:match("^.*dependencies(.*)$")
            if c then
                dep_section = true
                dep_section_start = i - 1
                dep_section_crate = nil
                dep_section_crate_name = c:match("^%.(.+)$")
            else
                dep_section = false
                dep_section_crate = nil
                dep_section_crate_name = nil
            end
        elseif dep_section and dep_section_crate_name then
            local crate = M.parse_crate_dep_section_line(l)
            if crate then
                crate.name = dep_section_crate_name
                crate.vers_line = i - 1
                dep_section_crate = crate
            end
        elseif dep_section then
            local crate = M.parse_dep_section_line(l)
            if crate then
                crate.line = { s = i - 1, e = i }
                crate.vers_line = i - 1
                table.insert(crates, crate)
            end
        end
    end

    for _,c in ipairs(crates) do
        c.reqs = semver.parse_requirements(c.req_text)

        c.req_has_suffix = false
        for _,r in ipairs(c.reqs) do
            if r.vers.suffix then
                c.req_has_suffix = true
                break
            end
        end
    end

    return crates
end

return M
