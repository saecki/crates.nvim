local record M
    record Section
        text: string
        invalid: boolean
        target: string|nil
        kind: Kind
        name: string|nil
        lines: Range

        enum Kind
            "default"
            "dev"
            "build"
        end
    end

    record Crate
        name: string
        lines: Range
        syntax: Syntax
        vers: Vers
        def: Def
        feat: Feat
        section: Section

        enum Syntax
            "plain"
            "inline_table"
            "table"
        end

        record Vers
            reqs: {Requirement}
            text: string
            is_pre: boolean
            line: integer -- 0-indexed
            col: Range
            decl_col: Range
            quote: Quotes
        end

        record Def
            enabled: boolean
            text: string
            line: integer -- 0-indexed
            col: Range
            decl_col: Range
        end

        record Feat
            items: {CrateFeature}
            text: string
            line: integer -- 0-indexed
            col: Range
            decl_col: Range
        end
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
        e: string|nil
    end
end

local Section = M.Section
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
            col = Range.new(fs as integer - 1, fe as integer - 1),
            decl_col = Range.new(fds as integer - 1, fde as integer - 1),
            quote = { s = qs, e = qe ~= "" and qe or nil },
            comma = c == ",",
        })
    end

    return feats
end

function Crate.new(obj: Crate): Crate
    if obj.vers then
        obj.vers.reqs = semver.parse_requirements(obj.vers.text)

        obj.vers.is_pre = false
        for _,r in ipairs(obj.vers.reqs) do
            if r.vers.pre then
                obj.vers.is_pre = true
                break
            end
        end
    end
    if obj.feat then
        obj.feat.items = M.parse_crate_features(obj.feat.text)
    end
    if obj.def then
        obj.def.enabled = obj.def.text ~= "false"
    end

    return setmetatable(obj, { __index = Crate })
end

function Crate:vers_reqs(): {Requirement}
    return self.vers and self.vers.reqs or {}
end

function Crate:vers_is_pre(): boolean|nil
    return self.vers and self.vers.is_pre
end

function Crate:get_feat(name: string): CrateFeature|nil, integer
    if not self.feat or not self.feat.items then
        return nil
    end

    for i,f in ipairs(self.feat.items) do
        if f.name == name then
            return f, i
        end
    end

    return nil
end

function Crate:feats(): {CrateFeature}
    return self.feat and self.feat.items or {}
end

function Crate:is_def_enabled(): boolean
    return not self.def or self.def.enabled
end

function Crate:cache_key(): string
    return string.format("%s:%s:%s", self.section.target or "", self.section.kind, self.name)
end


function M.parse_crate_table_vers(line: string): Crate
    local qs, vs, vers_text, ve, qe = line:match([[^%s*version%s*=%s*(["'])()([^"']*)()(["']?)%s*$]])
    if qs and vs and vers_text and ve then
        return {
            syntax = "table",
            vers = {
                text = vers_text,
                col = Range.new(vs as integer - 1, ve as integer - 1),
                decl_col = Range.new(0, line:len()),
                quote = { s = qs, e = qe ~= "" and qe or nil },
            }
        }
    end

    return nil
end

function M.parse_crate_table_feat(line: string): Crate
    local fs, feat_text, fe = line:match("%s*features%s*=%s*%[()([^%]]*)()[%]]?%s*$")
    if fs and feat_text and fe then
        return {
            syntax = "table",
            feat = {
                text = feat_text,
                col = Range.new(fs as integer - 1, fe as integer - 1),
                decl_col = Range.new(0, line:len()),
            }
        }
    end

    return nil
end

function M.parse_crate_table_def(line: string): Crate
    local ds, def_text, de = line:match("^%s*default[_-]features%s*=%s*()([^%s]*)()%s*$")
    if ds and def_text and de then
        return {
            syntax = "table",
            def = {
                text = def_text,
                col = Range.new(ds as integer - 1, de as integer - 1),
                decl_col = Range.new(0, line:len()),
            }
        }
    end

    return nil
end

function M.parse_crate(line: string): Crate
    local name: string
    local vds, qs, vs, vers_text, ve, qe, vde: string, string, string, string, string, string, string
    local fds, fs, feat_text, fe, fde: string, string, string, string, string
    local dds, ds, def_text, de, dde: string, string, string, string, string

    -- plain version
    name, qs, vs, vers_text, ve, qe = line:match([[^%s*([^%s]+)%s*=%s*(["'])()([^"']*)()(["']?)%s*$]])
    if name and qs and vs and vers_text and ve then
        return {
            name = name,
            syntax = "plain",
            vers = {
                text = vers_text,
                col = Range.new(vs as integer - 1, ve as integer - 1),
                decl_col = Range.new(0, line:len()),
                quote = { s = qs, e = qe ~= "" and qe or nil },
            }
        }
    end

    -- inline table
    local crate: Crate = {}

    local vers_pat = [[^%s*([^%s]+)%s*=%s*{.-[,]?()%s*version%s*=%s*(["'])()([^"']*)()(["']?)%s*()[,]?.*[}]?%s*$]]
    name, vds, qs, vs, vers_text, ve, qe, vde = line:match(vers_pat)
    if name and vds and qs and vs and vers_text and ve and qe and vde then
        crate.name = name
        crate.syntax = "inline_table"
        crate.vers = {
            text = vers_text,
            col = Range.new(vs as integer - 1, ve as integer - 1),
            decl_col = Range.new(vds as integer - 1, vde as integer - 1),
            quote = { s = qs, e = qe ~= "" and qe or nil },
        }
    end

    local feat_pat = "^%s*([^%s]+)%s*=%s*{.-[,]?()%s*features%s*=%s*%[()([^%]]*)()[%]]?%s*()[,]?.*[}]?%s*$"
    name, fds, fs, feat_text, fe, fde = line:match(feat_pat)
    if name and fds and fs and feat_text and fe and fde then
        crate.name = name
        crate.syntax = "inline_table"
        crate.feat = {
            text = feat_text,
            col = Range.new(fs as integer - 1, fe as integer - 1),
            decl_col = Range.new(fds as integer - 1, fde as integer - 1),
        }
    end

    local def_pat = "^%s*([^%s]+)%s*=%s*{.-[,]?()%s*default[_-]features%s*=%s*()([a-zA-Z]*)()%s*()[,]?.*[}]?%s*$"
    name, dds, ds, def_text, de, dde = line:match(def_pat)
    if name and dds and ds and def_text and de and dde then
        crate.name = name
        crate.syntax = "inline_table"
        crate.def = {
            text = def_text,
            col = Range.new(ds as integer - 1, de as integer - 1),
            decl_col = Range.new(dds as integer - 1, dde as integer - 1),
        }
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

function M.parse_crates(buf: integer): {Section}, {Crate}
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    local sections = {}
    local crates = {}

    local dep_section: Section = nil
    local dep_section_crate: Crate = nil

    for i,l in ipairs(lines) do
        l = M.trim_comments(l)

        local section = l:match("^%s*%[(.+)%]%s*$")

        if section then
            if dep_section then
                -- close line range
                dep_section.lines.e = i - 1

                -- push pending crate
                if dep_section_crate then
                    dep_section_crate.lines = dep_section.lines
                    table.insert(crates, Crate.new(dep_section_crate))
                end
            end

            local prefix, suffix = section:match("^(.*)dependencies(.*)$")
            if prefix and suffix then
                prefix = vim.trim(prefix)
                suffix = vim.trim(suffix)
                local target = prefix
                local name = suffix
                local kind: Section.Kind = "default"
                
                local dev_target = prefix:match("^(.*)dev%-$")
                if dev_target then
                    target = dev_target
                    kind = "dev"
                end
                
                local build_target = prefix:match("^(.*)build%-$")
                if build_target then
                    target = build_target
                    kind = "build"
                end

                if target then
                    target = target:match("^target%s*%.(.+)%.$")
                    target = target and vim.trim(target)
                end

                if suffix then
                    name = name:match("^%.(.+)$")
                    name = name and vim.trim(name)
                end

                local invalid = prefix ~= "" and not target and kind == "default"
                    or suffix ~= "" and not name

                dep_section_crate = nil
                dep_section = {
                    text = section,
                    invalid = invalid,
                    target = target,
                    kind = kind,
                    name = name,
                    lines = Range.new(i - 1, nil),
                }
                table.insert(sections, dep_section)
            else
                dep_section = nil
                dep_section_crate = nil
            end
        elseif dep_section and dep_section.name then
            local crate_vers = M.parse_crate_table_vers(l)
            if crate_vers then
                crate_vers.name = dep_section.name
                crate_vers.vers.line = i - 1
                crate_vers.section = dep_section
                dep_section_crate = vim.tbl_extend("keep", dep_section_crate or {}, crate_vers) as Crate
            end

            local crate_feat = M.parse_crate_table_feat(l)
            if crate_feat then
                crate_feat.name = dep_section.name
                crate_feat.feat.line = i - 1
                crate_feat.section = dep_section
                dep_section_crate = vim.tbl_extend("keep", dep_section_crate or {}, crate_feat) as Crate
            end

            local crate_def = M.parse_crate_table_def(l)
            if crate_def then
                crate_def.name = dep_section.name
                crate_def.def.line = i - 1
                crate_def.section = dep_section
                dep_section_crate = vim.tbl_extend("keep", dep_section_crate or {}, crate_def) as Crate
            end
        elseif dep_section then
            local crate = M.parse_crate(l)
            if crate then
                crate.lines = Range.new(i - 1, i)
                if crate.vers then
                    crate.vers.line = i - 1
                end
                if crate.def then
                    crate.def.line = i - 1
                end
                if crate.feat then
                    crate.feat.line = i - 1
                end
                crate.section = dep_section
                table.insert(crates, Crate.new(crate))
            end
        end
    end

    if dep_section then
        -- close line range
        dep_section.lines.e = #lines

        -- push pending crate
        if dep_section_crate then
            dep_section_crate.lines = dep_section.lines
            table.insert(crates, Crate.new(dep_section_crate))
        end
    end

    return sections, crates
end

return M
