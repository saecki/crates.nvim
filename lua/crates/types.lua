local M = {}

---@class CrateInfo
---@field lines Span
---@field vers_line integer
---@field vers_match ApiVersion|nil
---@field vers_update ApiVersion|nil
---@field vers_upgrade ApiVersion|nil
---@field match_kind MatchKind

---@enum MatchKind
M.MatchKind = {
    version = 1,
    yanked = 2,
    prerelease = 3,
    nomatch = 4,
}

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
---@field features ApiFeatures
---@field yanked boolean
---@field parsed SemVer
---@field created DateTime
---@field deps ApiDependency[]|nil

---@class ApiFeature
---@field name string
---@field members string[]

---@class ApiDependency
---@field name string
---@field opt boolean
---@field kind ApiDependencyKind
---@field vers ApiDependencyVers

---@enum ApiDependencyKind
M.DependencyKind = {
    normal = 1,
    build = 2,
    dev = 3,
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
    eq = "eq",
    lt = "lt",
    le = "le",
    gt = "gt",
    ge = "ge",
    cr = "cr",
    tl = "tl",
    wl = "wl",
    bl = "bl",
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

---keys of DiagnosticConfig
---@enum CratesDiagnosticKind
M.DiagnosticKind = {
    -- error
    section_invalid = "section_invalid",
    workspace_section_not_default = "workspace_section_not_default",
    workspace_section_has_target = "workspace_section_has_target",
    section_dup = "section_dup",
    crate_dup = "crate_dup",
    crate_novers = "crate_novers",
    crate_error_fetching = "crate_error_fetching",
    crate_name_case = "crate_name_case",
    vers_nomatch = "vers_nomatch",
    vers_yanked = "vers_yanked",
    vers_pre = "vers_pre",
    def_invalid = "def_invalid",
    feat_invalid = "feat_invalid",
    -- warning
    vers_upgrade = "vers_upgrade",
    feat_dup = "feat_dup",
    -- hint
    section_dup_orig = "section_dup_orig",
    crate_dup_orig = "crate_dup_orig",
    feat_dup_orig = "feat_dup_orig",
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
    for _,f in ipairs(list) do
        map[f.name] = f
    end
    return setmetatable({ list = list, map = map }, { __index = ApiFeatures })
end

---@param name string
---@return ApiFeature|nil
function ApiFeatures:get_feat(name)
    return self.map[name]
end

function ApiFeatures:sort()
    table.sort(self.list, function (a, b)
        if a.name == "default" then
            return true
        elseif b.name == "default" then
            return false
        else
            return a.name < b.name
        end
    end)
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

---@return string
function SemVer:display()
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
    return self.s <= pos and pos <  self.e
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
    return function()
        if i >= self.e then
            return nil
        end

        local val = i
        i = i + 1
        return val
    end
end

return M
