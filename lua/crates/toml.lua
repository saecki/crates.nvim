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
---@field end_line integer?
---@field end_col integer?

---@class TomlCrateVers: TomlCrateEntry
---@field reqs Requirement[]
---@field quote Quotes

---@class TomlCrateString: TomlCrateEntry
---@field quote Quotes

---@class TomlCrateBool: TomlCrateEntry
---@field enabled boolean

---@class TomlCrateFeat: TomlCrateEntry
---@field items TomlFeature[]
---0-based line of `]`. Same as `line` for a single-line array.
---@field end_line integer?
---0-based column of `]`. Same as `col.e` for a single-line array.
---@field end_col integer?

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
---0-based buffer line of this feature
---@field line integer
---name span on `line` (absolute column)
---@field col Span
---quote/whitespace span on `line` (absolute column)
---@field decl_col Span
---@field quote Quotes
---@field comma boolean
local TomlFeature = {}
M.TomlFeature = TomlFeature

---@class Quotes
---@field s string
---@field e string?


---@param text string
---@param offset integer 1-based index into text
---@param start_line integer
---@param start_col integer
---@return integer, integer
local function text_offset_to_pos(text, offset, start_line, start_col)
    local line = start_line
    local last_nl = 0
    for i = 1, offset - 1 do
        if text:byte(i) == 10 then
            line = line + 1
            last_nl = i
        end
    end
    if last_nl == 0 then
        return line, start_col + (offset - 1)
    end
    return line, (offset - 1) - last_nl
end

---@param text string
---@param start_line integer?
---@param start_col integer?
---@return TomlFeature[]
function M.parse_crate_features(text, start_line, start_col)
    start_line = start_line or 0
    start_col = start_col or 0
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
        local line, col_s = text_offset_to_pos(text, fs, start_line, start_col)
        local _, col_e = text_offset_to_pos(text, fe, start_line, start_col)
        local decl_line, decl_s = text_offset_to_pos(text, fds, start_line, start_col)
        local decl_end_line, decl_e = text_offset_to_pos(text, fde, start_line, start_col)
        -- Leading/trailing whitespace in `feat.text` can sit on a neighboring line.
        -- Columns are only valid on `line`.
        if decl_line ~= line then
            decl_s = 0
        end
        if decl_end_line ~= line then
            -- `col_e` is the exclusive name end (the closing quote). Keep the quote.
            decl_e = col_e
            if qe ~= "" then
                decl_e = col_e + 1
            end
        end
        ---@type TomlFeature
        local feat = {
            name = f,
            line = line,
            col = Span.new(col_s, col_e),
            decl_col = Span.new(decl_s, decl_e),
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
        obj.feat.items = M.parse_crate_features(obj.feat.text, obj.feat.line, obj.feat.col.s)
        if not obj.feat.end_line then
            obj.feat.end_line = obj.feat.line
            obj.feat.end_col = obj.feat.col.e
        end
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
    if not (prefix and suffix) then
        return nil
    end

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

    if target ~= "" then
        local t = target:match("^target%s*%.(.+)%.$")
        if t then
            section.target = vim.trim(t)
            target = ""
        else
            -- not a depndency section
            return nil
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

    section.invalid = (suffix ~= "")
        or (section.workspace and section.kind ~= TomlSectionKind.DEFAULT)
        or (section.workspace and section.target ~= nil)

    return Section.new(section)
end

---@param name string
---@return string
local function table_bool_pattern(name)
    return "^%s*" .. name .. "%s*=%s*()([^%s]*)()%s*$"
end

---@param name string
---@return string
local function table_str_pattern(name)
    return [[^%s*]] .. name .. [[%s*=%s*(["'])()([^"']*)()(["']?)%s*$]]
end

---@param name string
---@return string
local function table_str_array_pattern(name)
    return "%s*" .. name .. "%s*=%s*%[()([^%]]*)()[%]]%s*$"
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
    return "^%s*()([^%s]+)()%s*=%s*{.-[,]?()%s*" .. name .. "%s*=%s*%[()([^%]]*)()[%]]%s*()[,]?.*[}]?%s*$"
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

---Check if a line starts a multiline array for features
---@param line string
---@param name string
---@return integer?, string?, integer?
local function check_multiline_array_start(line, name)
    -- `array_s` is the 1-based index of the first char after `[`.
    -- Feature names cannot contain `]` (Cargo: ASCII alphanumeric, `_`, `-`, `+`).
    -- Reject keys that only *end* with `name` (`extra-features = [`).
    local before, decl_s, array_s, partial_text = line:match("^(.-)()" .. name .. "%s*=%s*%[()([^%]]*)$")
    if not array_s then
        return nil, nil, nil
    end
    local last = before:sub(-1)
    if before ~= "" and not last:match("[%s{,]") then
        return nil, nil, nil
    end
    return array_s, partial_text, decl_s
end

---@param feat TomlCrateFeat
---@param line integer
---@return boolean
function M.feat_contains_line(feat, line)
    local end_line = feat.end_line or feat.line
    return line >= feat.line and line <= end_line
end

---Parse remaining inline-table keys from the text after `]`.
---@param crate TomlCrate
---@param suffix string
---@param line_nr integer
---@param col_offset integer 0-based start of suffix on the line
local function parse_inline_suffix(crate, suffix, line_nr, col_offset)
    if not suffix:match("[^%s,}]") then
        return
    end

    ---@param key string
    ---@return table<string,any>?
    local function str_entry(key)
        local qs, str_s, text, str_e, qe = suffix:match(key .. [[%s*=%s*(["'])()([^"',%s}]*)()(["']?)]])
        if not text then
            return nil
        end
        return {
            text = text,
            line = line_nr,
            col = Span.new(col_offset + str_s - 1, col_offset + str_e - 1),
            decl_col = Span.new(col_offset, col_offset + #suffix),
            quote = { s = qs, e = qe ~= "" and qe or nil },
        }
    end

    ---@param key string
    ---@return table<string,any>?
    local function bool_entry(key)
        local bool_s, text, bool_e = suffix:match(key .. "%s*=%s*()([^%s,}]*)()")
        if not text or text == "" then
            return nil
        end
        return {
            text = text,
            line = line_nr,
            col = Span.new(col_offset + bool_s - 1, col_offset + bool_e - 1),
            decl_col = Span.new(col_offset, col_offset + #suffix),
        }
    end

    crate.vers = crate.vers or str_entry("version")
    crate.registry = crate.registry or str_entry("registry")
    crate.path = crate.path or str_entry("path")
    crate.git = crate.git or str_entry("git")
    crate.branch = crate.branch or str_entry("branch")
    crate.tag = crate.tag or str_entry("tag")
    crate.rev = crate.rev or str_entry("rev")
    crate.pkg = crate.pkg or str_entry("package")
    crate.def = crate.def or bool_entry("default[_-]features")
    crate.workspace = crate.workspace or bool_entry("workspace")
    crate.opt = crate.opt or bool_entry("optional")
end

---@param line string
---@return boolean
local function looks_like_assignment(line)
    return line:match("^%s*[%w._-]+%s*=") ~= nil
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

    -- Fallback: Check if it looks like an inline table start "name = {"
    local pattern = [[^%s*()([^%s]+)()%s*=%s*{]]
    local name_s, name, name_e = line:match(pattern)
    if name then
        crate.explicit_name = name
        crate.explicit_name_col = Span.new(name_s - 1, name_e - 1)
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

---@param buf integer
---@param crate TomlCrate
---@return TomlCrate?
function M.refresh_crate(buf, crate)
    local _, crates = M.parse_crates(buf)
    local key = crate:cache_key()
    for _, c in ipairs(crates) do
        if c:cache_key() == key then
            return c
        end
    end
    return nil
end

---@param crate TomlCrate
---@param feat table<string,any>
---@param line_nr integer
---@param suffix string
---@param closing_bracket_col integer 1-based index of `]`
local function finish_multiline_feat(crate, feat, line_nr, suffix, closing_bracket_col)
    feat.end_line = line_nr
    feat.end_col = closing_bracket_col - 1
    crate.feat = feat
    parse_inline_suffix(crate, suffix, line_nr, closing_bracket_col)
    if crate.syntax == TomlCrateSyntax.INLINE_TABLE then
        crate.lines.e = line_nr + 1
    end
end

---@param crate TomlCrate
---@param feat table<string,any>
---@param feat_lines string[]
local function apply_unclosed_feat(crate, feat, feat_lines)
    if not crate or not feat or not feat_lines then
        return
    end
    feat.text = table.concat(feat_lines, "\n")
    feat.end_line = feat.line + #feat_lines - 1
    feat.end_col = #(feat_lines[#feat_lines] or "")
    crate.feat = feat
    if crate.syntax == TomlCrateSyntax.INLINE_TABLE then
        crate.lines.e = feat.end_line + 1
    end
end

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
    ---@type table<string,any>?
    local multiline_feat
    ---@type string[]?
    local multiline_feat_lines

    for i, line in ipairs(lines) do
        line = M.trim_comments(line)
        local line_nr = i - 1

        ---@type string, string
        local section_start, section_text, section_end = line:match("^%s*()%[(.-)()%s*$")
        local handled = false
        if section_text then
            if dep_section then
                dep_section.lines.e = line_nr

                if dep_section_crate and dep_section_crate.syntax == TomlCrateSyntax.TABLE then
                    apply_unclosed_feat(dep_section_crate, multiline_feat, multiline_feat_lines)
                    dep_section_crate.lines = dep_section.lines
                    table.insert(crates, Crate.new(dep_section_crate))
                elseif dep_section_crate and dep_section_crate.syntax == TomlCrateSyntax.INLINE_TABLE then
                    apply_unclosed_feat(dep_section_crate, multiline_feat, multiline_feat_lines)
                    table.insert(crates, Crate.new(dep_section_crate))
                end
            end

            local header_col = Span.new(section_start - 1, section_end - 1)
            if section_text and section_text:sub(-1) == "]" then
                section_text = section_text:sub(1, -2)
            end

            dep_section = M.parse_section(section_text, line_nr, header_col)
            dep_section_crate = nil
            multiline_feat = nil
            multiline_feat_lines = nil
            if dep_section then
                table.insert(sections, dep_section)
            end
            handled = true
        elseif multiline_feat then
            -- Keep leading whitespace so feature columns match the buffer line.
            local content_before_close, suffix = line:match("^([^%]]*)%](.*)$")
            if content_before_close then
                table.insert(multiline_feat_lines, content_before_close)
                multiline_feat.text = table.concat(multiline_feat_lines, "\n")
                local closing_bracket_col = line:find("]", 1, true)

                if not dep_section_crate then
                    dep_section_crate = {
                        explicit_name = dep_section.name,
                        explicit_name_col = dep_section.name_col,
                        section = dep_section,
                        syntax = TomlCrateSyntax.TABLE,
                    }
                end

                finish_multiline_feat(
                    dep_section_crate,
                    multiline_feat,
                    line_nr,
                    suffix or "",
                    closing_bracket_col
                )
                multiline_feat = nil
                multiline_feat_lines = nil

                if dep_section_crate.syntax ~= TomlCrateSyntax.TABLE then
                    table.insert(crates, Crate.new(dep_section_crate))
                    dep_section_crate = nil
                end
                handled = true
            elseif looks_like_assignment(line) then
                apply_unclosed_feat(dep_section_crate, multiline_feat, multiline_feat_lines)
                multiline_feat = nil
                multiline_feat_lines = nil
                if dep_section_crate and dep_section_crate.syntax == TomlCrateSyntax.INLINE_TABLE then
                    table.insert(crates, Crate.new(dep_section_crate))
                    dep_section_crate = nil
                end
            else
                table.insert(multiline_feat_lines, line)
                handled = true
            end
        end

        if not handled and dep_section and dep_section.name then
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
            if tag then
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
            else
                local array_s, initial_content, decl_s = check_multiline_array_start(line, "features")
                if array_s then
                    dep_section_crate = dep_section_crate or empty_crate
                    multiline_feat_lines = { initial_content }
                    multiline_feat = {
                        text = "",
                        line = line_nr,
                        col = Span.new(array_s - 1, line:len()),
                        decl_col = Span.new((decl_s or 1) - 1, line:len()),
                    }
                end
            end
        elseif not handled and dep_section then
            local crate = M.parse_inline_crate(line, line_nr)
            if crate then
                crate.section = dep_section

                if not crate.feat then
                    local array_s, initial_content, decl_s = check_multiline_array_start(line, "features")
                    if array_s then
                        multiline_feat_lines = { initial_content }
                        multiline_feat = {
                            text = "",
                            line = line_nr,
                            col = Span.new(array_s - 1, line:len()),
                            decl_col = Span.new((decl_s or 1) - 1, line:len()),
                        }
                        dep_section_crate = crate
                    else
                        table.insert(crates, Crate.new(crate))
                    end
                else
                    table.insert(crates, Crate.new(crate))
                end
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
        dep_section.lines.e = #lines

        if dep_section_crate and dep_section_crate.syntax == TomlCrateSyntax.TABLE then
            apply_unclosed_feat(dep_section_crate, multiline_feat, multiline_feat_lines)
            dep_section_crate.lines = dep_section.lines
            table.insert(crates, Crate.new(dep_section_crate))
        elseif dep_section_crate and dep_section_crate.syntax == TomlCrateSyntax.INLINE_TABLE then
            apply_unclosed_feat(dep_section_crate, multiline_feat, multiline_feat_lines)
            table.insert(crates, Crate.new(dep_section_crate))
        end
    end

    return sections, crates, working_crates
end

return M
