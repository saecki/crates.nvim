local record M
end

local types = require("crates.types")
local Range = types.Range
local Requirement = types.Requirement
local SemVer = types.SemVer

function M.parse_version(str: string): SemVer
    local major, minor, patch, pre, meta: string, string, string, string, string

    major, minor, patch, pre, meta = str:match("^([0-9]+)%.([0-9]+)%.([0-9]+)-([^%s]+)%+([^%s]+)$")
    if major then
        return SemVer.new {
            major = tonumber(major) as integer,
            minor = tonumber(minor) as integer,
            patch = tonumber(patch) as integer,
            pre = pre,
            meta = meta,
        }
    end

    major, minor, patch, pre = str:match("^([0-9]+)%.([0-9]+)%.([0-9]+)-([^%s]+)$")
    if major then
        return SemVer.new {
            major = tonumber(major) as integer,
            minor = tonumber(minor) as integer,
            patch = tonumber(patch) as integer,
            pre = pre,
        }
    end

    major, minor, patch, meta = str:match("^([0-9]+)%.([0-9]+)%.([0-9]+)%+([^%s]+)$")
    if major then
        return SemVer.new {
            major = tonumber(major) as integer,
            minor = tonumber(minor) as integer,
            patch = tonumber(patch) as integer,
            meta = meta,
        }
    end

    major, minor, patch = str:match("^([0-9]+)%.([0-9]+)%.([0-9]+)$")
    if major then
        return SemVer.new {
            major = tonumber(major) as integer,
            minor = tonumber(minor) as integer,
            patch = tonumber(patch) as integer,
        }
    end

    major, minor = str:match("^([0-9]+)%.([0-9]+)[%.]?$")
    if major then
        return SemVer.new {
            major = tonumber(major) as integer,
            minor = tonumber(minor) as integer,
        }
    end

    major = str:match("^([0-9]+)[%.]?$")
    if major then
        return SemVer.new {
            major = tonumber(major) as integer,
        }
    end

    return SemVer.new {}
end

function M.parse_requirement(str: string): Requirement
    local vs, vers_str, ve, rs, re: integer, string, integer, integer, integer

    vs, vers_str, ve = str:match("^=%s*()(.+)()$") as (integer, string, integer)
    if vs and vers_str and ve then
        return {
            cond = "eq",
            cond_col = Range.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Range.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^<=%s*()(.+)()$") as (integer, string, integer)
    if vs and vers_str and ve then
        return {
            cond = "le",
            cond_col = Range.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Range.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^<%s*()(.+)()$") as (integer, string, integer)
    if vs and vers_str and ve then
        return {
            cond = "lt",
            cond_col = Range.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Range.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^>=%s*()(.+)()$") as (integer, string, integer)
    if vs and vers_str and ve then
        return {
            cond = "ge",
            cond_col = Range.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Range.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^>%s*()(.+)()$") as (integer, string, integer)
    if vs and vers_str and ve then
        return {
            cond = "gt",
            cond_col = Range.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Range.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^%~%s*()(.+)()$") as (integer, string, integer)
    if vs and vers_str and ve then
        return {
            cond = "tl",
            cond_col = Range.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Range.new(vs - 1, ve - 1),
        }
    end

    vers_str, rs, re = str:match("^(.+)()%.%*()$") as (string, integer, integer)
    if vers_str and rs and re then
        return {
            cond = "wl",
            cond_col = Range.new(rs - 1, re - 1),
            vers = M.parse_version(vers_str),
            vers_col = Range.new(0, rs - 1),
        }
    end

    vs, vers_str, ve = str:match("^%^%s*()(.+)()$") as (integer, string, integer)
    if vs and vers_str and ve then
        return {
            cond = "cr",
            cond_col = Range.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Range.new(vs - 1, ve - 1),
        }
    end

    return {
        cond = "bl",
        cond_col = Range.new(0, 0),
        vers = M.parse_version(str),
        vers_col = Range.new(0, str:len()),
    }
end

function M.parse_requirements(str: string): {Requirement}
    local requirements = {}
    for rs, r  in str:gmatch("[,]?%s*()([^,]+)%s*[,]?") do
        local s = rs as integer
        local requirement = M.parse_requirement(r)
        requirement.vers_col.s = requirement.vers_col.s + s - 1
        requirement.vers_col.e = requirement.vers_col.e + s - 1
        table.insert(requirements, requirement)
    end

    return requirements
end

local function filled_zeros(version: SemVer): SemVer
    return {
        major = version.major or 0,
        minor = version.minor or 0,
        patch = version.patch or 0,
        pre = version.pre,
    }
end

local function compare_pre(a: string, b: string): integer
    if a and b then
        if     a  < b then return -1
        elseif a == b then return 0
        elseif a  > b then return 1
        end
    end

    if         a and not b then return -1
    elseif not a and not b then return 0
    elseif not a and     b then return 1
    end
end

local function compare_versions(a: SemVer, b: SemVer): number
    local major = a.major - b.major
    local minor = a.minor - b.minor
    local patch = a.patch - b.patch
    local pre = compare_pre(a.pre, b.pre)

    if major == 0 then
        if minor == 0 then
            if patch == 0 then
                return pre
            else
                return patch
            end
        else
            return minor
        end
    else
        return major
    end
end

function M.is_lower(a: SemVer, b: SemVer): boolean
    return compare_versions(a, b) < 0
end

function M.matches_requirement(v: SemVer, r: Requirement): boolean
    if r.cond == "cr" or r.cond == "bl" then
        if r.vers.major == v.major and not r.vers.minor then
            return true
        end

        local a = filled_zeros(v)
        local b = filled_zeros(r.vers)
        local c: SemVer
        if b.major == 0 and b.minor == 0 then
            c = { major = 0, minor = 0, patch = b.patch + 1 }
        elseif b.major == 0 then
            c = { major = 0, minor = b.minor + 1, patch = 0 }
        else
            c = { major = b.major + 1, minor = 0, patch = 0 }
        end

        return compare_versions(a, b) >= 0
            and compare_versions(a, c) < 0
    end

    if r.cond == "tl" then
        local a = v
        local b = r.vers
        local c: SemVer
        if not b.minor and not b.patch then
            c = { major = b.major + 1, minor = 0, patch = 0 }
        else
            c = { major = b.major, minor = b.minor + 1, patch = 0 }
        end
        b = filled_zeros(b)

        return compare_versions(a, b) >= 0
            and compare_versions(a, c) < 0
    end

    if r.cond == "eq" or r.cond == "wl" then
        if r.vers.major ~= v.major then
            return false
        end
        if r.vers.minor and r.vers.minor ~= v.minor then
            return false
        end
        if r.vers.patch and r.vers.patch ~= v.patch then
            return false
        end
        return r.vers.pre == v.pre and r.vers.meta == v.meta
    elseif r.cond == "lt" then
        local a = filled_zeros(v)
        local b = filled_zeros(r.vers)
        return compare_versions(a, b) < 0
    elseif r.cond == "le" then
        local a = filled_zeros(v)
        local b = filled_zeros(r.vers)
        return compare_versions(a, b) <= 0
    elseif r.cond == "gt" then
        local a = filled_zeros(v)
        local b = filled_zeros(r.vers)
        return compare_versions(a, b) > 0
    elseif r.cond == "ge" then
        local a = filled_zeros(v)
        local b = filled_zeros(r.vers)
        return compare_versions(a, b) >= 0
    end
end

function M.matches_requirements(version: SemVer, requirements: {Requirement}): boolean
    for _,r in ipairs(requirements) do
        if not M.matches_requirement(version, r) then
            return false
        end
    end
    return true
end

return M
