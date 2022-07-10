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

    local wl = str:match("^%*$") as (string, integer, integer)
    if wl then
        return {
            cond = "wl",
            cond_col = Range.new(0, 1),
            vers = SemVer.new {},
            vers_col = Range.new(0, 0),
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

local function compare_pre(version: string, req: string): integer
    if version and req then
        if version < req then
            return -1
        elseif version == req then
            return 0
        elseif version > req then
            return 1
        end
    end

    return (req and 1 or 0) - (version and 1 or 0)
end

local function matches_less(version: SemVer, req: SemVer): boolean
    if req.major and req.major ~= version.major then
        return version.major < req.major
    end
    if req.minor and req.minor ~= version.minor then
        return version.minor < req.minor
    end
    if req.patch and req.patch ~= version.patch then
        return version.patch < req.patch
    end

    return compare_pre(version.pre, req.pre) < 0
end

local function matches_greater(version: SemVer, req: SemVer): boolean
    if req.major and req.major ~= version.major then
        return version.major > req.major
    end
    if req.minor and req.minor ~= version.minor then
        return version.minor > req.minor
    end
    if req.patch and req.patch ~= version.patch then
        return version.patch > req.patch
    end

    return compare_pre(version.pre, req.pre) > 0
end

local function matches_exact(version: SemVer, req: SemVer): boolean
    if req.major and req.major ~= version.major then
        return false
    end
    if req.minor and req.minor ~= version.minor then
        return false
    end
    if req.patch and req.patch ~= version.patch then
        return false
    end

    return version.pre == req.pre
end

local function matches_caret(version: SemVer, req: SemVer): boolean
    if req.major and req.major ~= version.major then
        return false
    end

    if not req.minor then
        return true
    end

    if not req.patch then
        if req.major > 0 then
            return version.minor >= req.minor
        else
            return version.minor == req.minor
        end
    end

    if req.major > 0 then
        if req.minor ~= version.minor then
            return version.minor > req.minor
        elseif req.patch ~= version.patch then
            return version.patch > req.patch
        end
    elseif req.minor > 0 then
        if req.minor ~= version.minor then
            return false
        elseif version.patch ~= req.patch then
            return version.patch > req.patch
        end
    elseif version.minor ~= req.minor or version.patch ~= req.patch then
        return false
    end

    return compare_pre(version.pre, req.pre) >= 0
end

local function matches_tilde(version: SemVer, req: SemVer): boolean
    if req.major and req.major ~= version.major then
        return false
    end
    if req.minor and req.minor ~= version.minor then
        return false
    end
    if req.patch and req.patch ~= version.patch then
        return version.patch > req.patch
    end

    return compare_pre(version.pre, req.pre) >= 0
end

function M.matches_requirement(v: SemVer, r: Requirement): boolean
    if r.cond == "cr" or r.cond == "bl" then
        return matches_caret(v, r.vers)
    elseif r.cond == "tl" then
        return matches_tilde(v, r.vers)
    elseif r.cond == "eq" or r.cond == "wl" then
        return matches_exact(v, r.vers)
    elseif r.cond == "lt" then
        return matches_less(v, r.vers)
    elseif r.cond == "le" then
        return matches_exact(v, r.vers) or matches_less(v, r.vers)
    elseif r.cond == "gt" then
        return matches_greater(v, r.vers)
    elseif r.cond == "ge" then
        return matches_exact(v, r.vers) or matches_greater(v, r.vers)
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
