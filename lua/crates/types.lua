local M = {}

---@class CrateInfo
---@field lines Span
---@field vers_line integer
---@field vers_match ApiVersion|nil
---@field vers_update ApiVersion|nil
---@field vers_upgrade ApiVersion|nil
---@field match_kind MatchKind

---NOTE: Used to index the user configuration, so keys have to be in sync
---@enum MatchKind
M.MatchKind = {
    VERSION = "version",
    YANKED = "yanked",
    PRERELEASE = "prerelease",
    NOMATCH = "nomatch"
}

---NOTE: Completion only shows a very minimal summary at the moment,
---`crates.io/api/v1/crates?q=<search>` gives a lot more information
---that may be displayed in the future.
---@class ApiCrateSummary
---@field name string
---@field description string
---@field newest_version string

---@class ApiCrate
---@field name string
---@field description string
---@field created DateTime
---@field updated DateTime
---@field downloads integer
---@field homepage string|nil
---@field repository string|nil
---@field documentation string|nil
---@field categories string[]
---@field keywords string[]
---@field versions ApiVersion[]

---@class ApiVersion
---@field num string
---@field parsed SemVer
---@field yanked boolean
---@field created DateTime
---@field features ApiFeatures
---@field deps ApiDependency[]

---@class ApiFeature
---@field name string
---@field members string[]
---@field dep boolean?

---@class ApiDependency
---@field name string
---@field package string
---@field opt boolean
---@field kind ApiDependencyKind
---@field vers ApiDependencyVers

---@enum ApiDependencyKind
M.ApiDependencyKind = {
    NORMAL = 1,
    BUILD = 2,
    DEV = 3,
}

---@class ApiDependencyVers
---@field reqs Requirement[]
---@field text string

---@class Requirement
---@field cond Cond
---@field cond_col Span
---@field vers SemVer
---@field vers_col Span

---@enum Cond
M.Cond = {
    EQ = 1,
    LT = 2,
    LE = 3,
    GT = 4,
    GE = 5,
    CR = 6,
    TL = 7,
    WL = 8,
    BL = 9,
}

---@class CratesDiagnostic
---@field lnum integer
---@field end_lnum integer
---@field col integer
---@field end_col integer
---@field severity integer
---@field kind CratesDiagnosticKind
---@field data table<string,any>|nil
local CratesDiagnostic = {}
M.CratesDiagnostic = CratesDiagnostic

---@param obj CratesDiagnostic
---@return CratesDiagnostic
function CratesDiagnostic.new(obj)
    return setmetatable(obj, { __index = CratesDiagnostic })
end

---@param line integer
---@param col integer
---@return boolean
function CratesDiagnostic:contains(line, col)
    return (self.lnum < line or self.lnum == line and self.col <= col)
        and (self.end_lnum > line or self.end_lnum == line and self.end_col > col)
end

---NOTE: Used to index the user configuration, so keys have to be in sync
---@enum CratesDiagnosticKind
M.CratesDiagnosticKind = {
    -- error
    SECTION_INVALID = "section_invalid",
    WORKSPACE_SECTION_NOT_DEFAULT = "workspace_section_not_default",
    WORKSPACE_SECTION_HAS_TARGET = "workspace_section_has_target",
    SECTION_DUP = "section_dup",
    CRATE_DUP = "crate_dup",
    CRATE_NOVERS = "crate_novers",
    CRATE_ERROR_FETCHING = "crate_error_fetching",
    CRATE_NAME_CASE = "crate_name_case",
    VERS_NOMATCH = "vers_nomatch",
    VERS_YANKED = "vers_yanked",
    VERS_PRE = "vers_pre",
    DEF_INVALID = "def_invalid",
    FEAT_INVALID = "feat_invalid",
    FEAT_EXPLICIT_DEP = "feat_explicit_dep",
    -- warning
    VERS_UPGRADE = "vers_upgrade",
    FEAT_DUP = "feat_dup",
    -- hint
    SECTION_DUP_ORIG = "section_dup_orig",
    CRATE_DUP_ORIG = "crate_dup_orig",
    FEAT_DUP_ORIG = "feat_dup_orig",
}

---@class ApiFeatures
---@field list ApiFeature[]
---@field map table<string,ApiFeature>
local ApiFeatures = {}
M.ApiFeatures = ApiFeatures

---@param list ApiFeature[]
---@return ApiFeatures
function ApiFeatures.new(list)
    ---@type table<string,ApiFeature>
    local map = {}
    for _, f in ipairs(list) do
        map[f.name] = f
    end
    return setmetatable({ list = list, map = map }, { __index = ApiFeatures })
end

---Returns the feature directly matching `name` or alternatively in `dep:name` syntax.
---@param name string
---@return ApiFeature|nil
function ApiFeatures:get_feat(name)
    return self.map[name] or self.map["dep:" .. name]
end

---@param feat ApiFeature
function ApiFeatures:insert(feat)
    table.insert(self.list, feat)
    self.map[feat.name] = feat
end

---@class SemVer
---@field major integer|nil
---@field minor integer|nil
---@field patch integer|nil
---@field pre string|nil
---@field meta string|nil
local SemVer = {}
M.SemVer = SemVer

---@param obj SemVer
---@return SemVer
function SemVer.new(obj)
    return setmetatable(obj, { __index = SemVer })
end

---Display the full verison *without* the build-metadata
---@return string
function SemVer:display_req()
    local text = ""
    if self.major then
        text = text .. self.major
    end

    if self.minor then
        text = text .. "." .. self.minor
    end

    if self.patch then
        text = text .. "." .. self.patch
    end

    if self.pre then
        text = text .. "-" .. self.pre
    end

    return text
end

---@return string
function SemVer:display()
    local text = self:display_req()

    if self.meta then
        text = text .. "+" .. self.meta
    end

    return text
end

---@class Span
---@field s integer -- 0-indexed inclusive
---@field e integer -- 0-indexed exclusive
local Span = {}
M.Span = Span

---@param s integer
---@param e integer
---@return Span
function Span.new(s, e)
    return setmetatable({ s = s, e = e }, { __index = Span })
end

---@param p integer
---@return Span
function Span.pos(p)
    return Span.new(p, p + 1)
end

---@return Span
function Span.empty()
    return Span.new(0, 0)
end

---@param pos integer
---@return boolean
function Span:contains(pos)
    return self.s <= pos and pos < self.e
end

---Create a new span with moved start and end bounds
---@param s integer
---@param e integer
---@return Span
function Span:moved(s, e)
    return Span.new(self.s + s, self.e + e)
end

---@return fun(): integer|nil
function Span:iter()
    local i = self.s
    local e = self.e
    return function()
        if i >= e then
            return nil
        end

        local val = i
        i = i + 1
        return val
    end
end

--- Converts it into the expected format for LSP completion items
---@param line integer
---@return lsp.Range
function Span:range(line)
    return {
        start = {
            line = line,
            character = self.s
        },
        ['end'] = {
            line = line,
            character = self.e
        },
    }
end

---@class WorkingCrate
---@field name string
---@field line integer
---@field col Span

return M
