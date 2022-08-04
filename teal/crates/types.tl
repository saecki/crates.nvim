local record M
    record CrateInfo
        lines: Range
        vers_line: integer
        vers_match: Version
        vers_update: Version
        vers_upgrade: Version
        match_kind: MatchKind
        dep_kind: DepKind
    end

    enum MatchKind
        "version"
        "yanked"
        "prerelease"
        "nomatch"
    end

    enum DepKind
        "registry"
        "path"
        "git"
    end

    record Diagnostic
        lnum: integer
        end_lnum: integer
        col: integer
        end_col: integer
        severity: integer
        kind: DiagnosticKind
        data: {string:any}
    end

    -- keys of DiagnosticConfig
    enum DiagnosticKind
        -- error
        "section_invalid"
        "section_dup"
        "crate_dup"
        "crate_novers"
        "crate_error_fetching"
        "vers_nomatch"
        "vers_yanked"
        "def_invalid"
        "feat_invalid"
        -- warning
        "vers_upgrade"
        "vers_pre"
        "feat_dup"
        -- hint
        "section_dup_orig"
        "crate_dup_orig"
        "feat_dup_orig"
    end

    record Crate
        name: string
        description: string
        created: DateTime
        updated: DateTime
        downloads: integer
        homepage: string|nil
        repository: string|nil
        documentation: string|nil
        categories: {string}
        keywords: {string}
    end

    record Version
        num: string
        features: Features
        yanked: boolean
        parsed: SemVer
        created: DateTime
        deps: {Dependency}|nil
    end

    record Features
        {Feature}
    end

    record Feature
        name: string
        members: {string}
    end

    record Dependency
        name: string
        opt: boolean
        kind: Kind
        vers: Vers

        enum Kind
            "normal"
            "build"
            "dev"
        end

        record Vers
            reqs: {Requirement}
            text: string
        end
    end

    record SemVer
        major: integer
        minor: integer
        patch: integer
        pre: string
        meta: string
    end

    record Requirement
        cond: Cond
        cond_col: Range -- relative to to the start of the requirement text
        vers: SemVer
        vers_col: Range -- relative to to the start of the requirement text
    end

    enum Cond
        "eq"
        "lt"
        "le"
        "gt"
        "ge"
        "cr"
        "tl"
        "wl"
        "bl"
    end

    record Range
        s: integer -- 0-indexed inclusive
        e: integer -- 0-indexed exclusive
    end
end

local Diagnostic = M.Diagnostic
local Feature = M.Feature
local Features = M.Features
local Range = M.Range
local SemVer = M.SemVer
local time = require("crates.time")
local DateTime = time.DateTime

function Diagnostic.new(obj: Diagnostic): Diagnostic
    return setmetatable(obj, { __index = Diagnostic })
end

function Diagnostic:contains(line: integer, col: integer): boolean
    return (self.lnum < line or self.lnum == line and self.col <= col)
        and (self.end_lnum > line or self.end_lnum == line and self.end_col > col)
end


function Features.new(obj: Features): Features
    return setmetatable(obj, { __index = Features })
end

function Features:get_feat(name: string): Feature|nil, integer|nil
    for i,f in ipairs(self) do
        if f.name == name then
            return f, i
        end
    end

    return nil, nil
end

function Features:sort()
    table.sort(self, function (a: Feature, b: Feature): boolean
        if a.name == "default" then
            return true
        elseif b.name == "default" then
            return false
        else
            return a.name < b.name
        end
    end)
end


function SemVer.new(obj: SemVer): SemVer
    return setmetatable(obj, { __index = SemVer })
end

function SemVer:display(): string
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


function Range.new(s: integer, e: integer): Range
    return setmetatable({ s = s, e = e }, { __index = Range })
end

function Range.pos(p: integer): Range
    return Range.new(p, p + 1)
end

function Range.empty(): Range
    return Range.new(0, 0)
end

function Range:contains(pos: integer): boolean
    return self.s <= pos and pos <  self.e
end

-- Create a new range with moved start and end bounds
function Range:moved(s: integer, e: integer): Range
    return Range.new(self.s + s, self.e + e)
end

function Range:iter(): function(): integer
    local i = self.s
    return function(): integer
        if i >= self.e then
            return nil
        end

        local val = i
        i = i + 1
        return val
    end
end

return M
