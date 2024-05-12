local semver = require("crates.semver")
local types = require("crates.types")
local Span = types.Span

local M = {}

---@class TomlSection
---@field text string
---@field invalid boolean|nil
---@field workspace boolean|nil
---@field target string|nil
---@field kind TomlSectionKind
---@field name string|nil
---@field name_col Span|nil
---@field lines Span
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
---@field vers TomlCrateVers|nil
---@field registry TomlCrateRegistry|nil
---@field path TomlCratePath|nil
---@field git TomlCrateGit|nil
---@field branch TomlCrateBranch|nil
---@field rev TomlCrateRev|nil
---@field pkg TomlCratePkg|nil
---@field workspace TomlCrateWorkspace|nil
---@field opt TomlCrateOpt|nil
---@field def TomlCrateDef|nil
---@field feat TomlCrateFeat|nil
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

---@class TomlCrateVers
---@field reqs Requirement[]
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span
---@field quote Quotes

---@class TomlCrateRegistry
---@field text string
---@field is_pre boolean
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span
---@field quote Quotes

---@class TomlCratePath
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span
---@field quote Quotes

---@class TomlCrateGit
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span
---@field quote Quotes

---@class TomlCrateBranch
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span
---@field quote Quotes

---@class TomlCrateRev
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span
---@field quote Quotes

---@class TomlCratePkg
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span
---@field quote Quotes

---@class TomlCrateWorkspace
---@field enabled boolean
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span

---@class TomlCrateOpt
---@field enabled boolean
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span

---@class TomlCrateDef
---@field enabled boolean
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span

---@class TomlCrateFeat
---@field items TomlFeature[]
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span

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
---@field e string|nil


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
    ---@param qe string|nil
    ---@param fde integer
    ---@param c string|nil
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
---@return TomlFeature|nil
---@return integer|nil
function Crate:get_feat(name)
    if not self.feat or not self.feat.items then
        return nil, nil
    end

    for i, f in ipairs(self.feat.items) do
        if f.name == name then
            return f, i
        end
    end

    return nil, nil
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

---@param override_name string|nil
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
---@param start integer
---@return TomlSection|nil
function M.parse_section(text, line_nr, start)
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
                local offset = start + suffix_s - 1
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

---@param line string
---@param line_nr integer
---@param pattern string
---@return table|nil
local function parse_crate_table_str(line, line_nr, pattern)
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

    return nil
end

---@param line string
---@param line_nr integer
---@param pattern string
---@return table|nil
local function parse_crate_table_bool(line, line_nr, pattern)
    local bool_s, text, bool_e = line:match(pattern)
    if text then
        return {
            text = text,
            line = line_nr,
            col = Span.new(bool_s - 1, bool_e - 1),
            decl_col = Span.new(0, line:len()),
        }
    end

    return nil
end

---@param line string
---@param line_nr integer
---@return TomlCrateVers|nil
function M.parse_crate_table_vers(line, line_nr)
    local pat = [[^%s*version%s*=%s*(["'])()([^"']*)()(["']?)%s*$]]
    return parse_crate_table_str(line, line_nr, pat)
end

---@param line string
---@param line_nr integer
---@return TomlCrateRegistry|nil
function M.parse_crate_table_registry(line, line_nr)
    local pat = [[^%s*registry%s*=%s*(["'])()([^"']*)()(["']?)%s*$]]
    return parse_crate_table_str(line, line_nr, pat)
end

---@param line string
---@param line_nr integer
---@return TomlCratePath|nil
function M.parse_crate_table_path(line, line_nr)
    local pat = [[^%s*path%s*=%s*(["'])()([^"']*)()(["']?)%s*$]]
    return parse_crate_table_str(line, line_nr, pat)
end

---@param line string
---@param line_nr integer
---@return TomlCrateGit|nil
function M.parse_crate_table_git(line, line_nr)
    local pat = [[^%s*git%s*=%s*(["'])()([^"']*)()(["']?)%s*$]]
    return parse_crate_table_str(line, line_nr, pat)
end

---@param line string
---@param line_nr integer
---@return TomlCrateBranch|nil
function M.parse_crate_table_branch(line, line_nr)
    local pat = [[^%s*branch%s*=%s*(["'])()([^"']*)()(["']?)%s*$]]
    return parse_crate_table_str(line, line_nr, pat)
end

---@param line string
---@param line_nr integer
---@return TomlCrateRev|nil
function M.parse_crate_table_rev(line, line_nr)
    local pat = [[^%s*rev%s*=%s*(["'])()([^"']*)()(["']?)%s*$]]
    return parse_crate_table_str(line, line_nr, pat)
end

---@param line string
---@param line_nr integer
---@return TomlCratePkg|nil
function M.parse_crate_table_pkg(line, line_nr)
    local pat = [[^%s*package%s*=%s*(["'])()([^"']*)()(["']?)%s*$]]
    return parse_crate_table_str(line, line_nr, pat)
end

---@param line string
---@param line_nr integer
---@return TomlCrateDef|nil
function M.parse_crate_table_def(line, line_nr)
    local pat = "^%s*default[_-]features%s*=%s*()([^%s]*)()%s*$"
    return parse_crate_table_bool(line, line_nr, pat)
end

---@param line string
---@param line_nr integer
---@return TomlCrateWorkspace|nil
function M.parse_crate_table_workspace(line, line_nr)
    local pat = "^%s*workspace%s*=%s*()([^%s]*)()%s*$"
    return parse_crate_table_bool(line, line_nr, pat)
end

---@param line string
---@param line_nr integer
---@return TomlCrateOpt|nil
function M.parse_crate_table_opt(line, line_nr)
    local pat = "^%s*optional%s*=%s*()([^%s]*)()%s*$"
    return parse_crate_table_bool(line, line_nr, pat)
end

---@param line string
---@param line_nr integer
---@return TomlCrateFeat|nil
function M.parse_crate_table_feat(line, line_nr)
    local array_s, text, array_e = line:match("%s*features%s*=%s*%[()([^%]]*)()[%]]?%s*$")
    if text then
        return {
            text = text,
            line = line_nr,
            col = Span.new(array_s - 1, array_e - 1),
            decl_col = Span.new(0, line:len()),
        }
    end

    return nil
end

---@param name string
---@return string
local function inline_table_bool_pattern(name)
    return "^%s*()([^%s]+)()%s*=%s*{.-[,]?()%s*" .. name .. "%s*=%s*()([^%s,}]*)()%s*()[,]?.*[}]?%s*$"
end

---@param name string
---@return string
local function inline_table_str_pattern(name)
    return [[^%s*()([^%s]+)()%s*=%s*{.-[,]?()%s*]] .. name .. [[%s*=%s*(["'])()([^"']*)()(["']?)%s*()[,]?.*[}]?%s*$]]
end

---@param name string
---@return string
local function inline_table_str_array_pattern(name)
    return "^%s*()([^%s]+)()%s*=%s*{.-[,]?()%s*" .. name .. "%s*=%s*%[()([^%]]*)()[%]]?%s*()[,]?.*[}]?%s*$"
end

local INLINE_TABLE_VERS_PATTERN = inline_table_str_pattern("version")
local INLINE_TABLE_REGISTRY_PATTERN = inline_table_str_pattern("registry")
local INLINE_TABLE_PATH_PATTERN = inline_table_str_pattern("path")
local INLINE_TABLE_GIT_PATTERN = inline_table_str_pattern("git")
local INLINE_TABLE_BRANCH_PATTERN = inline_table_str_pattern("branch")
local INLINE_TABLE_REV_PATTERN = inline_table_str_pattern("rev")
local INLINE_TABLE_PKG_PATTERN = inline_table_str_pattern("package")
local INLINE_TABLE_FEAT_PATTERN = inline_table_str_array_pattern("features")
local INLINE_TABLE_DEF_PATTERN = inline_table_bool_pattern("default[_-]features")
local INLINE_TABLE_WORKSPACE_PATTERN = inline_table_bool_pattern("workspace")
local INLINE_TABLE_OPT_PATTERN = inline_table_bool_pattern("optional")

---@param line string
---@param line_nr integer
---@param pattern string
---@return string|nil
---@return Span
---@return table<string,any>
local function parse_inline_table_str(line, line_nr, pattern)
    local name_s, name, name_e, decl_s, quote_s, str_s, text, str_e, quote_e, decl_e = line:match(pattern)
    if name then
        local name_col = Span.new(name_s - 1, name_e - 1)
        local entry = {
            text = text,
            line = line_nr,
            col = Span.new(str_s - 1, str_e - 1),
            decl_col = Span.new(decl_s - 1, decl_e - 1),
            quote = { s = quote_s, e = quote_e ~= "" and quote_e or nil },
        }

        return name, name_col, entry
    end
end

---comment
---@param line string
---@param line_nr integer
---@param pattern string
---@return string|nil
---@return Span
---@return table<string,any>
local function parse_inline_table_bool(line, line_nr, pattern)
    local name_s, name, name_e, decl_s, str_s, text, str_e, decl_e = line:match(pattern)
    if name then
        local name_col = Span.new(name_s - 1, name_e - 1)
        local entry = {
            text = text,
            line = line_nr,
            col = Span.new(str_s - 1, str_e - 1),
            decl_col = Span.new(decl_s - 1, decl_e - 1),
        }
        return name, name_col, entry
    end
end

---comment
---@param line string
---@param line_nr integer
---@return TomlCrate|nil
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

    do
        local name, name_col, vers = parse_inline_table_str(line, line_nr, INLINE_TABLE_VERS_PATTERN)
        if name then
            crate.explicit_name = name
            crate.explicit_name_col = name_col
            crate.vers = vers
        end
    end

    do
        local name, name_col, registry = parse_inline_table_str(line, line_nr, INLINE_TABLE_REGISTRY_PATTERN)
        if name then
            crate.explicit_name = name
            crate.explicit_name_col = name_col
            crate.registry = registry
        end
    end

    do
        local name, name_col, path = parse_inline_table_str(line, line_nr, INLINE_TABLE_PATH_PATTERN)
        if name then
            crate.explicit_name = name
            crate.explicit_name_col = name_col
            crate.path = path
        end
    end

    do
        local name, name_col, git = parse_inline_table_str(line, line_nr, INLINE_TABLE_GIT_PATTERN)
        if name then
            crate.explicit_name = name
            crate.explicit_name_col = name_col
            crate.git = git
        end
    end

    do
        local name, name_col, branch = parse_inline_table_str(line, line_nr, INLINE_TABLE_BRANCH_PATTERN)
        if name then
            crate.explicit_name = name
            crate.explicit_name_col = name_col
            crate.branch = branch
        end
    end

    do
        local name, name_col, rev = parse_inline_table_str(line, line_nr, INLINE_TABLE_REV_PATTERN)
        if name then
            crate.explicit_name = name
            crate.explicit_name_col = name_col
            crate.rev = rev
        end
    end

    do
        local name, name_col, pkg = parse_inline_table_str(line, line_nr, INLINE_TABLE_PKG_PATTERN)
        if name then
            crate.explicit_name = name
            crate.explicit_name_col = name_col
            crate.pkg = pkg
        end
    end

    do
        local name, name_col, def = parse_inline_table_bool(line, line_nr, INLINE_TABLE_DEF_PATTERN)
        if name then
            crate.explicit_name = name
            crate.explicit_name_col = name_col
            crate.def = def
        end
    end

    do
        local name, name_col, workspace = parse_inline_table_bool(line, line_nr, INLINE_TABLE_WORKSPACE_PATTERN)
        if name then
            crate.explicit_name = name
            crate.explicit_name_col = name_col
            crate.workspace = workspace
        end
    end

    do
        local name, name_col, opt = parse_inline_table_bool(line, line_nr, INLINE_TABLE_OPT_PATTERN)
        if name then
            crate.explicit_name = name
            crate.explicit_name_col = name_col
            crate.opt = opt
        end
    end

    do
        local name_s, name, name_e, decl_s, array_s, text, array_e, decl_e = line:match(INLINE_TABLE_FEAT_PATTERN)
        if name then
            crate.explicit_name = name
            crate.explicit_name_col = Span.new(name_s - 1, name_e - 1)
            crate.feat = {
                text = text,
                line = line_nr,
                col = Span.new(array_s - 1, array_e - 1),
                decl_col = Span.new(decl_s - 1, decl_e - 1),
            }
        end
    end

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

        local section_start, section_text = line:match("^%s*%[()([^%]]+)%]?%s*$")

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

            dep_section = M.parse_section(section_text, line_nr, section_start - 1)
            dep_section_crate = nil
            if dep_section then
                if dep_section.name then
                    table.insert(working_crates, {
                        name = dep_section.name,
                        span = dep_section.name_col,
                        kind = types.WorkingCrateKind.TABLE,
                        line = line_nr,
                    })
                end

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

            local vers = M.parse_crate_table_vers(line, line_nr)
            if vers then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.vers = vers
            end

            local registry = M.parse_crate_table_registry(line, line_nr)
            if registry then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.registry = registry
            end

            local path = M.parse_crate_table_path(line, line_nr)
            if path then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.path = path
            end

            local git = M.parse_crate_table_git(line, line_nr)
            if git then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.git = git
            end

            local branch = M.parse_crate_table_branch(line, line_nr)
            if branch then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.branch = branch
            end

            local rev = M.parse_crate_table_rev(line, line_nr)
            if rev then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.rev = rev
            end

            local pkg = M.parse_crate_table_pkg(line, line_nr)
            if pkg then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.pkg = pkg
            end

            local def = M.parse_crate_table_def(line, line_nr)
            if def then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.def = def
            end

            local workspace = M.parse_crate_table_workspace(line, line_nr)
            if workspace then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.workspace = workspace
            end

            local opt = M.parse_crate_table_opt(line, line_nr)
            if opt then
                dep_section_crate = dep_section_crate or empty_crate
                dep_section_crate.opt = opt
            end

            local feat = M.parse_crate_table_feat(line, line_nr)
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
                        span = Span.new(name_s - 1, name_e - 1),
                        kind = types.WorkingCrateKind.INLINE,
                        line = line_nr,
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
