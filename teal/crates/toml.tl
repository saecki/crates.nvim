local record M
    record Crate
        name: string
        lines: Range
        syntax: string
        reqs: {Requirement}|nil
        req_text: string|nil
        req_has_suffix: boolean|nil
        req_line: number|nil -- 0-indexed
        req_col: Range|nil
        req_decl_col: Range|nil
        req_quote: Quotes|nil
        feats: {CrateFeature}|nil
        feat_text: string|nil
        feat_line: number|nil -- 0-indexed
        feat_col: Range|nil
        feat_decl_col: Range|nil
        def: boolean|nil
        def_text: string|nil
        def_line: number|nil -- 0-indexed
        def_col: Range|nil
        def_decl_col: Range|nil
    end

    record CrateFeature
        name: string
        col: Range -- relative to to the start of the features text
        decl_col: Range -- relative to to the start of the features text
        quote: Quotes
        comma: boolean
    end

    record Quotes
        s: string
        e: string
    end
end

local Crate = M.Crate
local CrateFeature = M.CrateFeature
local semver = require('crates.semver')
local Requirement = semver.Requirement
local Range = require('crates.types').Range

function M.parse_crate_features(text: string): {CrateFeature}
    local feats: {CrateFeature} = {}
    for fds, qs, fs, f, fe, qe, fde, c in text:gmatch([[[,]?()%s*(["'])()([^,"']*)()(["']?)%s*()([,]?)]]) do
        table.insert(feats, {
            name = f,
            col = Range.new(tonumber(fs) - 1, tonumber(fe) - 1),
            decl_col = Range.new(tonumber(fds) - 1, tonumber(fde) - 1),
            quotes = { s = qs, e = qe ~= "" and qe or nil },
            comma = c == ",",
        })
    end

    return feats
end

function M.parse_crate_table_req(line: string): Crate|nil
    local qs, vs, req_text, ve, qe = line:match([[^%s*version%s*=%s*(["'])()([^"']*)()(["']?)%s*$]])
    if qs and vs and req_text and ve then
        return {
            req_text = req_text,
            req_col = Range.new(tonumber(vs) - 1, tonumber(ve) - 1),
            req_decl_col = Range.new(0, line:len()),
            req_quote = { s = qs, e = qe ~= "" and qe or nil },
            syntax = "table",
        } as Crate
    end

    return nil
end


function Crate.new(obj: Crate): Crate
    if obj.req_text then
        obj.reqs = semver.parse_requirements(obj.req_text)

        obj.req_has_suffix = false
        for _,r in ipairs(obj.reqs as {Requirement}) do
            if r.vers.suffix then
                obj.req_has_suffix = true
                break
            end
        end
    end
    if obj.feat_text then
        obj.feats = M.parse_crate_features(obj.feat_text)
    end
    if obj.def_text then
        obj.def = obj.def_text ~= "false"
    end

    return setmetatable(obj, { __index = Crate })
end

function Crate:get_feat(name: string): CrateFeature|nil, integer
    if not self.feats then return nil end

    for i,f in ipairs(self.feats as {CrateFeature}) do
        if f.name == name then
            return f, i
        end
    end

    return nil
end

function M.parse_crate_table_feat(line: string): Crate|nil
    local fs, feat_text, fe = line:match("%s*features%s*=%s*%[()([^%]]*)()[%]]?%s*$")
    if fs and feat_text and fe then
        return {
            feat_text = feat_text,
            feat_col = Range.new(tonumber(fs) - 1, tonumber(fe) - 1),
            feat_decl_col = Range.new(0, line:len()),
            syntax = "table",
        } as Crate
    end

    return nil
end

function M.parse_crate_table_def(line: string): Crate|nil
    local ds, def_text, de = line:match("^%s*default[_-]features%s*=%s*()([^%s]*)()%s*$")
    if ds and def_text and de then
        return {
            def_text = def_text,
            def_col = Range.new(tonumber(ds) - 1, tonumber(de) - 1),
            def_decl_col = Range.new(0, line:len()),
            syntax = "table",
        } as Crate
    end

    return nil
end

function M.parse_crate(line: string): Crate|nil
    local name: string
    local vds, qs, vs, req_text, ve, qe, vde: string, string, string, string, string, string, string
    local fds, fs, feat_text, fe, fde: string, string, string, string, string
    local dds, ds, def_text, de, dde: string, string, string, string, string

    -- plain version
    name, qs, vs, req_text, ve, qe = line:match([[^%s*([^%s]+)%s*=%s*(["'])()([^"']*)()(["']?)%s*$]])
    if name and qs and vs and req_text and ve then
        return {
            name = name,
            req_text = req_text,
            req_col = Range.new(tonumber(vs) - 1, tonumber(ve) - 1),
            req_decl_col = Range.new(0, line:len()),
            req_quote = { s = tonumber(qs), e = tonumber(qe) },
            syntax = "plain",
        } as Crate
    end

    -- inline table
    local crate: Crate = {}

    local vers_pat = [[^%s*([^%s]+)%s*=%s*{.-[,]?()%s*version%s*=%s*(["'])()([^"']*)()(["']?)%s*()[,]?.*[}]?%s*$]]
    name, vds, qs, vs, req_text, ve, qe, vde = line:match(vers_pat)
    if name and vds and qs and vs and req_text and ve and qe and vde then
        crate.name = name
        crate.req_text = req_text
        crate.req_col = Range.new(tonumber(vs) - 1, tonumber(ve) - 1)
        crate.req_decl_col = Range.new(tonumber(vds) - 1, tonumber(vde) - 1)
        crate.req_quote = { s = qs, e = qe ~= "" and qe or nil }
        crate.syntax = "inline_table"
    end

    local feat_pat = "^%s*([^%s]+)%s*=%s*{.-[,]?()%s*features%s*=%s*%[()([^%]]*)()[%]]?%s*()[,]?.*[}]?%s*$"
    name, fds, fs, feat_text, fe, fde = line:match(feat_pat)
    if name and fds and fs and feat_text and fe and fde then
        crate.name = name
        crate.feat_text = feat_text
        crate.feat_col = Range.new(tonumber(fs) - 1, tonumber(fe) - 1)
        crate.feat_decl_col = Range.new(tonumber(fds) - 1, tonumber(fde) - 1)
        crate.syntax = "inline_table"
    end

    local def_pat = "^%s*([^%s]+)%s*=%s*{.-[,]?()%s*default[_-]features%s*=%s*()([a-zA-Z]*)()%s*()[,]?.*[}]?%s*$"
    name, dds, ds, def_text, de, dde = line:match(def_pat)
    if name and dds and ds and def_text and de and dde then
        crate.name = name
        crate.def_text = def_text
        crate.def_col = Range.new(tonumber(ds) - 1, tonumber(de) - 1)
        crate.def_decl_col = Range.new(tonumber(dds) - 1, tonumber(dde) - 1)
        crate.syntax = "inline_table"
    end

    if crate.name then
        return crate
    else
        return nil
    end
end

function M.trim_comments(line: string): string
    local uncommented = line:match("^([^#]*)#.*$")
    return uncommented or line
end

function M.parse_crates(buf: integer): {Crate}
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    local crates = {}
    local in_dep_table = false
    local dep_table_start: integer = 0
    local dep_table_crate: Crate = nil
    local dep_table_crate_name: string = nil -- [dependencies.<crate>]

    for i,l in ipairs(lines) do
        l = M.trim_comments(l)

        local section = l:match("^%s*%[(.+)%]%s*$")

        if section then
            -- push pending crate
            if dep_table_crate then
                dep_table_crate.lines = Range.new(dep_table_start, i - 1)
                table.insert(crates, Crate.new(dep_table_crate))
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
            local crate_req = M.parse_crate_table_req(l) as Crate
            if crate_req then
                crate_req.name = dep_table_crate_name
                crate_req.req_line = i - 1
                dep_table_crate = vim.tbl_extend("keep", dep_table_crate as table or {}, crate_req as table) as Crate
            end

            local crate_feat = M.parse_crate_table_feat(l) as Crate
            if crate_feat then
                crate_feat.name = dep_table_crate_name
                crate_feat.feat_line = i - 1
                dep_table_crate = vim.tbl_extend("keep", dep_table_crate as table or {}, crate_feat as table) as Crate
            end

            local crate_def = M.parse_crate_table_def(l) as Crate
            if crate_def then
                crate_def.name = dep_table_crate_name
                crate_def.def_line = i - 1
                dep_table_crate = vim.tbl_extend("keep", dep_table_crate as table or {}, crate_def as table) as Crate
            end
        elseif in_dep_table then
            local crate = M.parse_crate(l) as Crate
            if crate then
                crate.lines = Range.new(i - 1, i)
                crate.req_line = i - 1
                crate.feat_line = i - 1
                crate.def_line = i - 1
                table.insert(crates, Crate.new(crate))
            end
        end
    end

    -- push pending crate
    if dep_table_crate then
        dep_table_crate.lines = Range.new(dep_table_start, #lines - 1)
        table.insert(crates, Crate.new(dep_table_crate))
    end

    return crates
end

return M
