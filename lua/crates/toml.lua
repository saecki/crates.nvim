---@class Crate
---@field name string
---@field line Range
---@field syntax string
---@field reqs Requirement[]
---@field req_text string
---@field req_has_suffix boolean
---@field req_line integer -- 0-indexed
---@field req_col Range
---@field req_quote Quotes

---@class Quotes
---@field s string
---@field e string

local M = {}

local semver = require('crates.semver')

---@param line string
---@return Crate
function M.parse_crate_table_entry(line)
    local qs, vs, req_text, ve, qe = line:match([[^%s*version%s*=%s*(["'])()([^"']*)()(["']?)%s*$]])
    if qs and vs and req_text and ve then
        return {
            req_text = req_text,
            req_col = { s = vs - 1, e = ve },
            req_quote = { s = qs, e = qe ~= "" and qe or nil },
            syntax = "table",
        }
    end

    return nil
end

---@param line string
---@return Crate
function M.parse_crate(line)
    local name, qs, vs, req_text, ve, qe
    -- plain version
    name, qs, vs, req_text, ve, qe = line:match([[^%s*([^%s]+)%s*=%s*(["'])()([^"']*)()(["']?)%s*$]])
    if name and qs and vs and req_text and ve then
        return {
            name = name,
            req_text = req_text,
            req_col = { s = vs - 1, e = ve },
            req_quote = { s = qs, e = qe ~= "" and qe or nil },
            syntax = "normal",
        }
    end

    -- version in inline table
    local pat = [[^%s*([^%s]+)%s*=%s*{.*[,]?%s*version%s*=%s*(["'])()([^"']*)()(["']?)%s*[,]?.*[}]?%s*$]]
    name, qs, vs, req_text, ve, qe = line:match(pat)
    if name and qs and vs and req_text and ve then
        return {
            name = name,
            req_text = req_text,
            req_col = { s = vs - 1, e = ve },
            req_quote = { s = qs, e = qe ~= "" and qe or nil },
            syntax = "inline_table",
        }
    end

    return nil
end

---@param buf integer
---@return Crate[]
function M.parse_crates(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    local crates = {}
    local in_dep_table = false
    local dep_table_start = 0
    local dep_table_crate = nil
    local dep_table_crate_name = nil -- [dependencies.<crate>]

    for i,l in ipairs(lines) do
        local uncommented = l:match("^([^#]*)#.*$")
        if uncommented then
            l = uncommented
        end

        local section = l:match("^%s*%[(.+)%]%s*$")

        if section then
            -- push pending crate
            if dep_table_crate then
                dep_table_crate.line = { s = dep_table_start, e = i - 1 }
                table.insert(crates, dep_table_crate)
            end

            local c = section:match("^.*dependencies(.*)$")
            if c then
                in_dep_table = true
                dep_table_start = i - 1
                dep_table_crate = nil
                dep_table_crate_name = c:match("^%.(.+)$")
            else
                in_dep_table = false
                dep_table_crate = nil
                dep_table_crate_name = nil
            end
        elseif in_dep_table and dep_table_crate_name then
            local crate = M.parse_crate_table_entry(l)
            if crate then
                crate.name = dep_table_crate_name
                crate.req_line = i - 1
                dep_table_crate = crate
            end
        elseif in_dep_table then
            local crate = M.parse_crate(l)
            if crate then
                crate.line = { s = i - 1, e = i }
                crate.req_line = i - 1
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
