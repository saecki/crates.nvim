---@class Crate
---@field name string
---@field lines Range
---@field syntax string
---@field reqs Requirement[]
---@field req_text string
---@field req_has_suffix boolean
---@field req_line integer -- 0-indexed
---@field req_col Range
---@field req_decl_col Range
---@field req_quote Quotes
---@field feats string[]
---@field feat_text string
---@field feat_line integer -- 0-indexed
---@field feat_col Range
---@field feat_decl_col Range

---@class Quotes
---@field s string
---@field e string

local M = {}

local semver = require('crates.semver')
local Range = require('crates.types').Range

---@param line string
---@return Crate
function M.parse_crate_table_req(line)
    local qs, vs, req_text, ve, qe = line:match([[^%s*version%s*=%s*(["'])()([^"']*)()(["']?)%s*$]])
    if qs and vs and req_text and ve then
        return {
            req_text = req_text,
            req_col = Range.new(vs - 1,ve),
            req_decl_col = Range.new(0, line:len()),
            req_quote = { s = qs, e = qe ~= "" and qe or nil },
            syntax = "table",
        }
    end

    return nil
end

---@param line string
---@return Crate
function M.parse_crate_table_feat(line)
    local fs, feat_text, fe = line:match("%s*features%s*=%s*%[()([^%]]*)()[%]]?%s*$")
    if fs and feat_text and fe then
        return {
            feat_text = feat_text,
            feat_col = Range.new(fs -1, fe),
            feat_decl_col = Range.new(0, line:len()),
            syntax = "table",
        }
    end

    return nil
end

---@param line string
---@return Crate
function M.parse_crate(line)
    local name, vds, qs, vs, req_text, ve, qe, vde, fds, fs, feat_text, fe, fde
    -- plain version
    name, qs, vs, req_text, ve, qe = line:match([[^%s*([^%s]+)%s*=%s*(["'])()([^"']*)()(["']?)%s*$]])
    if name and qs and vs and req_text and ve then
        return {
            name = name,
            req_text = req_text,
            req_col = Range.new(vs - 1, ve),
            req_decl_col = Range.new(0, line:len()),
            req_quote = { s = qs, e = qe ~= "" and qe or nil },
            syntax = "plain",
        }
    end

    -- inline table
    local crate = {}

    local vers_pat = [[^%s*([^%s]+)%s*=%s*{.*[,]?()%s*version%s*=%s*(["'])()([^"']*)()(["']?)%s*()[,]?.*[}]?%s*$]]
    name, vds, qs, vs, req_text, ve, qe, vde = line:match(vers_pat)
    if name and vds and qs and vs and req_text and ve and qe and vde then
        crate.name = name
        crate.req_text = req_text
        crate.req_col = Range.new(vs - 1, ve)
        crate.req_decl_col = Range.new(vds - 1, vde)
        crate.req_quote = { s = qs, e = qe ~= "" and qe or nil }
        crate.syntax = "inline_table"
    end

    local feat_pat = "^%s*([^%s]+)%s*=%s*{.*[,]?()%s*features%s*=%s*%[()([^%]]*)()[%]]?%s*()[,]?.*[}]?%s*$"
    name, fds, fs, feat_text, fe, fde = line:match(feat_pat)
    if name and fds and fs and feat_text and fe and fde then
        crate.name = name
        crate.feat_text = feat_text
        crate.feat_col = Range.new(fs - 1, fe)
        crate.feat_decl_col = Range.new(fds - 1, fde)
        crate.syntax = "inline_table"
    end

    if crate.name then
        return crate
    else
        return nil
    end
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
                dep_table_crate.lines = Range.new(dep_table_start, i - 1)
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
            local crate_req = M.parse_crate_table_req(l)
            if crate_req then
                crate_req.name = dep_table_crate_name
                crate_req.req_line = i - 1
                dep_table_crate = vim.tbl_extend("keep", dep_table_crate or {}, crate_req)
            end

            local crate_feat = M.parse_crate_table_feat(l)
            if crate_feat then
                crate_feat.name = dep_table_crate_name
                crate_feat.feat_line = i - 1
                dep_table_crate = vim.tbl_extend("keep", dep_table_crate or {}, crate_feat)
            end
        elseif in_dep_table then
            local crate = M.parse_crate(l)
            if crate then
                crate.lines = Range.new(i - 1, i)
                crate.req_line = i - 1
                crate.feat_line = i - 1
                table.insert(crates, crate)
            end
        end
    end

    -- push pending crate
    if dep_table_crate then
        dep_table_crate.lines = Range.new(dep_table_start, #lines - 1)
        table.insert(crates, dep_table_crate)
    end


    for _,c in ipairs(crates) do
        if c.req_text then
            c.reqs = semver.parse_requirements(c.req_text)

            c.req_has_suffix = false
            for _,r in ipairs(c.reqs) do
                if r.vers.suffix then
                    c.req_has_suffix = true
                    break
                end
            end
        end
        if c.feat_text then
            c.feats = {}
            for s in c.feat_text:gmatch([[[,]?%s*["']([^,"']+)["']?%s*[,]?]]) do
                table.insert(c.feats, s)
            end
        end
    end

    return crates
end

return M
