local semver = require("crates.semver")
local types = require("crates.types")
local Span = types.Span

local M = {}

---@class TomlSection
---@field text string
---@field invalid boolean?
---@field workspace boolean?
---@field target string?
---@field kind TomlSectionKind
---@field name string?
---@field name_col Span?
---@field lines Span
---@field header_col Span
local Section = {}
M.Section = Section

---@enum TomlSectionKind
local TomlSectionKind = {
    DEFAULT = 1,
    DEV = 2,
    BUILD = 3,
}
M.TomlSectionKind = TomlSectionKind

---@class TomlCrate
--- The explicit name is either the name of the package, or a rename
--- if the following syntax is used:
--- explicit_name = { package = "package" }
---@field explicit_name string
---@field explicit_name_col Span
---@field lines Span
---@field syntax TomlCrateSyntax
---@field vers TomlCrateVers?
---@field registry TomlCrateString?
---@field path TomlCrateString?
---@field git TomlCrateString?
---@field branch TomlCrateString?
---@field tag TomlCrateString?
---@field rev TomlCrateString?
---@field pkg TomlCrateString?
---@field workspace TomlCrateBool?
---@field opt TomlCrateBool?
---@field def TomlCrateBool?
---@field feat TomlCrateFeat?
---@field section TomlSection
---@field dep_kind DepKind
local Crate = {}
M.Crate = Crate

---@enum TomlCrateSyntax
local TomlCrateSyntax = {
    PLAIN = 1,
    INLINE_TABLE = 2,
    TABLE = 3,
}
M.TomlCrateSyntax = TomlCrateSyntax

---@class TomlCrateEntry
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span
---@field text string

---@class TomlCrateVers: TomlCrateEntry
---@field reqs Requirement[]
---@field quote Quotes

---@class TomlCrateString: TomlCrateEntry
---@field quote Quotes

---@class TomlCrateBool: TomlCrateEntry
---@field enabled boolean

---@class TomlCrateFeat: TomlCrateEntry
---@field items TomlFeature[]

---@enum DepKind
local DepKind = {
    REGISTRY = 1,
    PATH = 2,
    GIT = 3,
    WORKSPACE = 4,
}
M.DepKind = DepKind

---@class TomlFeature
---@field name string
---relative to to the start of the features text
---@field col Span
---relative to to the start of the features text
---@field decl_col Span
---@field quote Quotes
---@field comma boolean
local TomlFeature = {}
M.TomlFeature = TomlFeature

---@class Quotes
---@field s string
---@field e string?


---@param text string
---@return TomlFeature[]
function M.parse_crate_features(text)
    ---@type TomlFeature[]
    local feats = {}
    ---@param fds integer
    ---@param qs string
    ---@param fs integer
    ---@param f string
    ---@param fe integer
    ---@param qe string?
    ---@param fde integer
    ---@param c string?
    for fds, qs, fs, f, fe, qe, fde, c in text:gmatch([[[,]?()%s*(["'])()([^,"']*)()(["']?)%s*()([,]?)]]) do
        ---@type TomlFeature
        local feat = {
            name = f,
            col = Span.new(fs - 1, fe - 1),
            decl_col = Span.new(fds - 1, fde - 1),
            quote = { s = qs, e = qe ~= "" and qe or nil },
            comma = c == ",",
        }
        table.insert(feats, feat)
    end

    return feats
end

---@param obj TomlCrate
---@return TomlCrate
function Crate.new(obj)
    if obj.vers then
        obj.vers.reqs = semver.parse_requirements(obj.vers.text)
    end
    if obj.feat then
        obj.feat.items = M.parse_crate_features(obj.feat.text)
    end
    if obj.def then
        obj.def.enabled = obj.def.text ~= "false"
    end
    if obj.workspace then
        obj.workspace.enabled = obj.workspace.text ~= "false"
    end
    if obj.opt then
        obj.opt.enabled = obj.opt.text ~= "false"
    end

    if obj.workspace then
        obj.dep_kind = DepKind.WORKSPACE
    elseif obj.path then
        obj.dep_kind = DepKind.PATH
    elseif obj.git then
        obj.dep_kind = DepKind.GIT
    else
        obj.dep_kind = DepKind.REGISTRY
    end

    return setmetatable(obj, { __index = Crate })
end

---@return Requirement[]
function Crate:vers_reqs()
    return self.vers and self.vers.reqs or {}
end

---@param name string
---@return TomlFeature?
function Crate:get_feat(name)
    if not self.feat or not self.feat.items then
        return nil
    end

    for _, f in ipairs(self.feat.items) do
        if f.name == name then
            return f
        end
    end

    return nil
end

---@return TomlFeature[]
function Crate:feats()
    return self.feat and self.feat.items or {}
end

---@return boolean
function Crate:is_def_enabled()
    return not self.def or self.def.enabled
end

---@return boolean
function Crate:is_workspace()
    return not self.workspace or self.workspace.enabled
end

---@return string
function Crate:package()
    return self.pkg and self.pkg.text or self.explicit_name
end

---@return integer, Span
function Crate:package_pos()
    if self.pkg then
        return self.pkg.line, self.pkg.col
    else
        return self.lines.s, self.explicit_name_col
    end
end

---@return string
function Crate:cache_key()
    return string.format(
        "%s:%s:%s:%s",
        self.section.target or "",
        self.section.workspace and "workspace" or "",
        self.section.kind,
        self.explicit_name
    )
end

---@param obj TomlSection
---@return TomlSection
function Section.new(obj)
    return setmetatable(obj, { __index = Section })
end

---@param override_name string?
---@return string
function Section:display(override_name)
    local text = "["

    if self.target then
        text = text .. self.target .. "."
    end

    if self.workspace then
        text = text .. "workspace."
    end

    if self.kind == TomlSectionKind.DEFAULT then
        text = text .. "dependencies"
    elseif self.kind == TomlSectionKind.DEV then
        text = text .. "dev-dependencies"
    elseif self.kind == TomlSectionKind.BUILD then
        text = text .. "build-dependencies"
    end

    local name = override_name or self.name
    if name then
        text = text .. "." .. name
    end

    text = text .. "]"

    return text
end

---@param text string
---@param line_nr integer
---@param header_col Span
---@return TomlSection?
function M.parse_section(text, line_nr, header_col)
    ---@type string, integer, string
    local prefix, suffix_s, suffix = text:match("^(.*)dependencies()(.*)$")
    if prefix and suffix then
        prefix = vim.trim(prefix)
        suffix = vim.trim(suffix)
        ---@type TomlSection
        local section = {
            text = text,
            invalid = false,
            kind = TomlSectionKind.DEFAULT,
            ---end bound is assigned when the section ends
            ---@diagnostic disable-next-line: param-type-mismatch
            lines = Span.new(line_nr, nil),
            header_col = header_col,
        }

        local target = prefix

        local dev_target = prefix:match("^(.*)dev%-$")
        if dev_target then
            target = vim.trim(dev_target)
            section.kind = TomlSectionKind.DEV
        end

        local build_target = prefix:match("^(.*)build%-$")
        if build_target then
            target = vim.trim(build_target)
            section.kind = TomlSectionKind.BUILD
        end

        local workspace_target = target:match("^(.*)workspace%s*%.$")
        if workspace_target then
            section.workspace = true
            target = vim.trim(workspace_target)
        end

        if target then
            local t = target:match("^target%s*%.(.+)%.$")
            if t then
                section.target = vim.trim(t)
                target = ""
            end
        end

        if suffix then
            local n_s, n, n_e = suffix:match("^%.%s*()(.+)()%s*$")
            if n then
                section.name = vim.trim(n)
                local offset = header_col.s + 1 + suffix_s - 1
                section.name_col = Span.new(n_s - 1 + offset, n_e - 1 + offset)
                suffix = ""
            end
        end

        section.invalid = (target ~= "" or suffix ~= "")
            or (section.workspace and section.kind ~= TomlSectionKind.DEFAULT)
            or (section.workspace and section.target ~= nil)

        return Section.new(section)
    end

    return nil
end

---@param name string
---@return string
local function table_bool_pattern(name)
    return "^%s*".. name .. "%s*=%s*()([^%s]*)()%s*$"
end

---@param name string
---@return string
local function table_str_pattern(name)
    return [[^%s*]] .. name .. [[%s*=%s*(["'])()([^"']*)()(["']?)%s*$]]
end

---@param name string
---@return string
local function table_str_array_pattern(name)
    return "%s*" .. name .. "%s*=%s*%[()([^%]]*)()[%]]?%s*$"
end

---@param name string
---@return string
local function inline_table_bool_pattern(name)
    return "^%s*()([^%s]+)()%s*=%s*{.-[,]?()%s*" .. name .. "%s*=%s*()([^%s,}]*)()%s*()[,]?.*[}]?%s*$"
end

---@param name string
---@return string
local function inline_table_str_pattern(name)
    return [[^%s*()([^%s]+)()%s*=%s*{.-[,]?()%s*]] .. name .. [[%s*=%s*(["'])()([^"',%s}]*)()(["']?)%s*()[,]?.*[}]?%s*$]]
end

---@param name string
---@return string
local function inline_table_str_array_pattern(name)
    return "^%s*()([^%s]+)()%s*=%s*{.-[,]?()%s*" .. name .. "%s*=%s*%[()([^%]]*)()[%]]?%s*()[,]?.*[}]?%s*$"
end

M.TABLE_VERS_PATTERN = table_str_pattern("version")
M.TABLE_REGISTRY_PATTERN = table_str_pattern("registry")
M.TABLE_PATH_PATTERN = table_str_pattern("path")
M.TABLE_GIT_PATTERN = table_str_pattern("git")
M.TABLE_BRANCH_PATTERN = table_str_pattern("branch")
M.TABLE_TAG_PATTERN = table_str_pattern("tag")
M.TABLE_REV_PATTERN = table_str_pattern("rev")
M.TABLE_PKG_PATTERN = table_str_pattern("package")
M.TABLE_FEAT_PATTERN = table_str_array_pattern("features")
M.TABLE_DEF_PATTERN = table_bool_pattern("default[_-]features")
M.TABLE_WORKSPACE_PATTERN = table_bool_pattern("workspace")
M.TABLE_OPT_PATTERN = table_bool_pattern("optional")

M.INLINE_TABLE_VERS_PATTERN = inline_table_str_pattern("version")
M.INLINE_TABLE_REGISTRY_PATTERN = inline_table_str_pattern("registry")
M.INLINE_TABLE_PATH_PATTERN = inline_table_str_pattern("path")
M.INLINE_TABLE_GIT_PATTERN = inline_table_str_pattern("git")
M.INLINE_TABLE_BRANCH_PATTERN = inline_table_str_pattern("branch")
M.INLINE_TABLE_TAG_PATTERN = inline_table_str_pattern("tag")
M.INLINE_TABLE_REV_PATTERN = inline_table_str_pattern("rev")
M.INLINE_TABLE_PKG_PATTERN = inline_table_str_pattern("package")
M.INLINE_TABLE_FEAT_PATTERN = inline_table_str_array_pattern("features")
M.INLINE_TABLE_DEF_PATTERN = inline_table_bool_pattern("default[_-]features")
M.INLINE_TABLE_WORKSPACE_PATTERN = inline_table_bool_pattern("workspace")
M.INLINE_TABLE_OPT_PATTERN = inline_table_bool_pattern("optional")

---@param line string
---@param line_nr integer
---@param pattern string
---@return table<string,any>?
function M.parse_crate_table_str(line, line_nr, pattern)
    local quote_s, str_s, text, str_e, quote_e = line:match(pattern)
    if text then
        return {
            text = text,
            line = line_nr,
            col = Span.new(str_s - 1, str_e - 1),
            decl_col = Span.new(0, line:len()),
            quote = { s = quote_s, e = quote_e ~= "" and quote_e or nil },
        }
    end
end

---@param line string
---@param line_nr integer
---@param pattern string
---@return table<string,any>?
function M.parse_crate_table_str_array(line, line_nr, pattern)
    local array_s, text, array_e = line:match(pattern)
    if text then
        return {
            text = text,
            line = line_nr,
            col = Span.new(array_s - 1, array_e - 1),
            decl_col = Span.new(0, line:len()),
        }
    end
end

---@param line string
---@param line_nr integer
---@param pattern string
---@return table<string,any>?
function M.parse_crate_table_bool(line, line_nr, pattern)
    local bool_s, text, bool_e = line:match(pattern)
    if text then
        return {
            text = text,
            line = line_nr,
            col = Span.new(bool_s - 1, bool_e - 1),
            decl_col = Span.new(0, line:len()),
        }
    end
end

---@param crate TomlCrate
---@param line string
---@param line_nr integer
---@param pattern string
---@return table<string,any>?
local function parse_inline_table_str(crate, line, line_nr, pattern)
    local name_s, name, name_e, decl_s, quote_s, str_s, text, str_e, quote_e, decl_e = line:match(pattern)
    if name then
        crate.explicit_name = name
        crate.explicit_name_col = Span.new(name_s - 1, name_e - 1)
        return {
            text = text,
            line = line_nr,
            col = Span.new(str_s - 1, str_e - 1),
            decl_col = Span.new(decl_s - 1, decl_e - 1),
            quote = { s = quote_s, e = quote_e ~= "" and quote_e or nil },
        }
    end
end

---@param crate TomlCrate
---@param line string
---@param line_nr integer
---@param pattern string
---@return table<string,any>?
local function parse_inline_table_str_array(crate, line, line_nr, pattern)
    local name_s, name, name_e, decl_s, array_s, text, array_e, decl_e = line:match(pattern)
    if name then
        crate.explicit_name = name
        crate.explicit_name_col = Span.new(name_s - 1, name_e - 1)
        return {
            text = text,
            line = line_nr,
            col = Span.new(array_s - 1, array_e - 1),
            decl_col = Span.new(decl_s - 1, decl_e - 1),
        }
    end
end

---comment
---@param crate TomlCrate
---@param line string
---@param line_nr integer
---@param pattern string
---@return table<string,any>?
local function parse_inline_table_bool(crate, line, line_nr, pattern)
    local name_s, name, name_e, decl_s, str_s, text, str_e, decl_e = line:match(pattern)
    if name then
        crate.explicit_name = name
        crate.explicit_name_col = Span.new(name_s - 1, name_e - 1)
        return {
            text = text,
            line = line_nr,
            col = Span.new(str_s - 1, str_e - 1),
            decl_col = Span.new(decl_s - 1, decl_e - 1),
        }
    end
end

---comment
---@param line string
---@param line_nr integer
---@return TomlCrate?
function M.parse_inline_crate(line, line_nr)
    -- plain version
    do
        local pat = [[^%s*()([^%s]+)()%s*=%s*(["'])()([^"']*)()(["']?)%s*$]]
        local name_s, name, name_e, quote_s, str_s, text, str_e, quote_e = line:match(pat)
        if name then
            ---@type TomlCrate
            return {
                explicit_name = name,
                explicit_name_col = Span.new(name_s - 1, name_e - 1),
                lines = Span.new(line_nr, line_nr + 1),
                syntax = TomlCrateSyntax.PLAIN,
                vers = {
                    text = text,
                    line = line_nr,
                    col = Span.new(str_s - 1, str_e - 1),
                    decl_col = Span.new(0, line:len()),
                    quote = { s = quote_s, e = quote_e ~= "" and quote_e or nil },
                }
            }
        end
    end

    -- inline table
    ---@type TomlCrate
    local crate = {
        syntax = TomlCrateSyntax.INLINE_TABLE,
        lines = Span.new(line_nr, line_nr + 1),
    }
    crate.vers = parse_inline_table_str(crate, line, line_nr, M.INLINE_TABLE_VERS_PATTERN)
    crate.registry = parse_inline_table_str(crate, line, line_nr, M.INLINE_TABLE_REGISTRY_PATTERN)
    crate.path = parse_inline_table_str(crate, line, line_nr, M.INLINE_TABLE_PATH_PATTERN)
    crate.git = parse_inline_table_str(crate, line, line_nr, M.INLINE_TABLE_GIT_PATTERN)
    crate.branch = parse_inline_table_str(crate, line, line_nr, M.INLINE_TABLE_BRANCH_PATTERN)
    crate.tag = parse_inline_table_str(crate, line, line_nr, M.INLINE_TABLE_TAG_PATTERN)
    crate.rev = parse_inline_table_str(crate, line, line_nr, M.INLINE_TABLE_REV_PATTERN)
    crate.pkg = parse_inline_table_str(crate, line, line_nr, M.INLINE_TABLE_PKG_PATTERN)
    crate.def = parse_inline_table_bool(crate, line, line_nr, M.INLINE_TABLE_DEF_PATTERN)
    crate.workspace = parse_inline_table_bool(crate, line, line_nr, M.INLINE_TABLE_WORKSPACE_PATTERN)
    crate.opt = parse_inline_table_bool(crate, line, line_nr, M.INLINE_TABLE_OPT_PATTERN)
    crate.feat = parse_inline_table_str_array(crate, line, line_nr, M.INLINE_TABLE_FEAT_PATTERN)

    if crate.explicit_name then
        return crate
    end

    return nil
end

---@param line string
---@return string
function M.trim_comments(line)
    local uncommented = line:match("^([^#]*)#.*$")
    return uncommented or line
end

---comment
---@param buf integer
---@return TomlSection[]
---@return TomlCrate[]
---@return WorkingCrate[]
function M.parse_crates(buf)
    ---@type string[]
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    local sections = {}
    local crates = {}

    ---@type TomlSection?
    local dep_section
    ---@type TomlCrate?
    local dep_section_crate
    ---@type WorkingCrate[]
    local working_crates = {}

    for i, line in ipairs(lines) do
        line = M.trim_comments(line)
        local line_nr = i - 1

        ---@type string, string
        local section_start, section_text, section_end = line:match("^%s*()%[(.+)()%s*$")
        if section_text then
            if dep_section then
                -- close line span
                dep_section.lines.e = line_nr

                -- push pending crate
                if dep_section_crate then
                    dep_section_crate.lines = dep_section.lines
                    table.insert(crates, Crate.new(dep_section_crate))
                end
            end

            local header_col = Span.new(section_start - 1, section_end - 1)
            if section_text and section_text:sub(-1) == ']' then
                section_text = section_text:sub(1, -2)
            end

            dep_section = M.parse_section(section_text, line_nr, header_col)
            dep_section_crate = nil
            if dep_section then
                table.insert(sections, dep_section)
            end
        elseif dep_section and dep_section.name then
            ---@class EmptyCrate: TomlCrate
            local empty_crate = {
                explicit_name = dep_section.name,
                explicit_name_col = dep_section.name_col,
                section = dep_section,
                syntax = TomlCrateSyntax.TABLE,
            }

            local vers = M.parse_crate_table_str(line, line_nr, M.TABLE_VERS_PATTERN)
            if vers then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.vers = vers
            end
            local registry = M.parse_crate_table_str(line, line_nr, M.TABLE_REGISTRY_PATTERN)
            if registry then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.registry = registry
            end

            local path = M.parse_crate_table_str(line, line_nr, M.TABLE_PATH_PATTERN)
            if path then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.path = path
            end

            local git = M.parse_crate_table_str(line, line_nr, M.TABLE_GIT_PATTERN)
            if git then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.git = git
            end
            local branch = M.parse_crate_table_str(line, line_nr, M.TABLE_BRANCH_PATTERN)
            if branch then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.branch = branch
            end
            local tag = M.parse_crate_table_str(line, line_nr, M.TABLE_TAG_PATTERN)
            if branch then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.tag = tag
            end
            local rev = M.parse_crate_table_str(line, line_nr, M.TABLE_REV_PATTERN)
            if rev then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.rev = rev
            end
            local pkg = M.parse_crate_table_str(line, line_nr, M.TABLE_PKG_PATTERN)
            if pkg then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.pkg = pkg
            end
            local def = M.parse_crate_table_bool(line, line_nr, M.TABLE_DEF_PATTERN)
            if def then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.def = def
            end
            local workspace = M.parse_crate_table_bool(line, line_nr, M.TABLE_WORKSPACE_PATTERN)
            if workspace then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.workspace = workspace
            end
            local opt = M.parse_crate_table_bool(line, line_nr, M.TABLE_OPT_PATTERN)
            if opt then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.opt = opt
            end
            local feat = M.parse_crate_table_str_array(line, line_nr, M.TABLE_FEAT_PATTERN)
            if feat then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.feat = feat
            end

        elseif dep_section then
            local crate = M.parse_inline_crate(line, line_nr)
            if crate then
                crate.section = dep_section
                table.insert(crates, Crate.new(crate))
            else
                local name_s, name, name_e = line:match [[^%s*()([^%s]+)()%s*$]]
                if name_s and name and name_e then
                    table.insert(working_crates, {
                        name = name,
                        line = line_nr,
                        col = Span.new(name_s - 1, name_e - 1),
                    })
                end
            end
        end
    end

    if dep_section then
        -- close line span
        dep_section.lines.e = #lines

        -- push pending crate
        if dep_section_crate then
            dep_section_crate.lines = dep_section.lines
            table.insert(crates, Crate.new(dep_section_crate))
        end
    end

    return sections, crates, working_crates
end

return M
