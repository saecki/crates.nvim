local types = require("crates.types")
local Cond = types.Cond
local SemVer = types.SemVer
local Span = types.Span

local M = {}

---@param str string
---@return SemVer
function M.parse_version(str)
    ---@type string, string, string, string, string
    local major, minor, patch, pre, meta

    major, minor, patch, pre, meta = str:match("^([0-9]+)%.([0-9]+)%.([0-9]+)-([^%s]+)%+([^%s]+)$")
    if major then
        return SemVer.new({
            major = tonumber(major),
            minor = tonumber(minor),
            patch = tonumber(patch),
            pre = pre,
            meta = meta,
        })
    end

    major, minor, patch, pre = str:match("^([0-9]+)%.([0-9]+)%.([0-9]+)-([^%s]+)$")
    if major then
        return SemVer.new({
            major = tonumber(major),
            minor = tonumber(minor),
            patch = tonumber(patch),
            pre = pre,
        })
    end

    major, minor, patch, meta = str:match("^([0-9]+)%.([0-9]+)%.([0-9]+)%+([^%s]+)$")
    if major then
        return SemVer.new({
            major = tonumber(major),
            minor = tonumber(minor),
            patch = tonumber(patch),
            meta = meta,
        })
    end

    major, minor, patch = str:match("^([0-9]+)%.([0-9]+)%.([0-9]+)$")
    if major then
        return SemVer.new({
            major = tonumber(major),
            minor = tonumber(minor),
            patch = tonumber(patch),
        })
    end

    major, minor = str:match("^([0-9]+)%.([0-9]+)[%.]?$")
    if major then
        return SemVer.new({
            major = tonumber(major),
            minor = tonumber(minor),
        })
    end

    major = str:match("^([0-9]+)[%.]?$")
    if major then
        return SemVer.new({
            major = tonumber(major),
        })
    end

    return SemVer.new({})
end

---@param str string
---@return Requirement
function M.parse_requirement(str)
    ---@type integer, string, integer, integer, integer
    local vs, vers_str, ve, rs, re

    vs, vers_str, ve = str:match("^=%s*()(.+)()$")
    if vs and vers_str and ve then
        ---@type Requirement
        return {
            cond = Cond.EQ,
            cond_col = Span.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Span.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^<=%s*()(.+)()$")
    if vs and vers_str and ve then
        ---@type Requirement
        return {
            cond = Cond.LE,
            cond_col = Span.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Span.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^<%s*()(.+)()$")
    if vs and vers_str and ve then
        ---@type Requirement
        return {
            cond = Cond.LT,
            cond_col = Span.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Span.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^>=%s*()(.+)()$")
    if vs and vers_str and ve then
        ---@type Requirement
        return {
            cond = Cond.GE,
            cond_col = Span.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Span.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^>%s*()(.+)()$")
    if vs and vers_str and ve then
        ---@type Requirement
        return {
            cond = Cond.GT,
            cond_col = Span.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Span.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^%~%s*()(.+)()$")
    if vs and vers_str and ve then
        ---@type Requirement
        return {
            cond = Cond.TL,
            cond_col = Span.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Span.new(vs - 1, ve - 1),
        }
    end

    local wl = str:match("^%*$")
    if wl then
        ---@type Requirement
        return {
            cond = Cond.WL,
            cond_col = Span.new(0, 1),
            vers = SemVer.new({}),
            vers_col = Span.new(0, 0),
        }
    end

    vers_str, rs, re = str:match("^(.+)()%.%*()$")
    if vers_str and rs and re then
        ---@type Requirement
        return {
            cond = Cond.WL,
            cond_col = Span.new(rs - 1, re - 1),
            vers = M.parse_version(vers_str),
            vers_col = Span.new(0, rs - 1),
        }
    end

    vs, vers_str, ve = str:match("^%^%s*()(.+)()$")
    if vs and vers_str and ve then
        ---@type Requirement
        return {
            cond = Cond.CR,
            cond_col = Span.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Span.new(vs - 1, ve - 1),
        }
    end

    ---@type Requirement
    return {
        cond = Cond.BL,
        cond_col = Span.new(0, 0),
        vers = M.parse_version(str),
        vers_col = Span.new(0, str:len()),
    }
end

---@param str string
---@return Requirement[]
function M.parse_requirements(str)
    ---@type Requirement[]
    local requirements = {}
    ---@param s integer
    ---@param r string
    for s, r in str:gmatch("[,]?%s*()([^,]+)%s*[,]?") do
        local requirement = M.parse_requirement(r)
        requirement.vers_col.s = requirement.vers_col.s + s - 1
        requirement.vers_col.e = requirement.vers_col.e + s - 1
        table.insert(requirements, requirement)
    end

    return requirements
end

-- TODO: port https://github.com/dtolnay/semver/blob/master/src%2Fimpls.rs#L51-L107
---@param version? string
---@param req? string
---@return integer
function M.compare_pre(version, req)
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

-- TODO: port https://github.com/dtolnay/semver/blob/master/src/impls.rs#L109-L153
---@param version? string
---@param req? string
---@return integer
function M.compare_meta(version, req)
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

---@param version SemVer
---@param req SemVer
---@return boolean
local function matches_less(version, req)
    if req.major and req.major ~= version.major then
        return version.major < req.major
    end
    if req.minor and req.minor ~= version.minor then
        return version.minor < req.minor
    end
    if req.patch and req.patch ~= version.patch then
        return version.patch < req.patch
    end

    return M.compare_pre(version.pre, req.pre) < 0
end

---@param version SemVer
---@param req SemVer
---@return boolean
local function matches_greater(version, req)
    if req.major and req.major ~= version.major then
        return version.major > req.major
    end
    if req.minor and req.minor ~= version.minor then
        return version.minor > req.minor
    end
    if req.patch and req.patch ~= version.patch then
        return version.patch > req.patch
    end

    return M.compare_pre(version.pre, req.pre) > 0
end

---@param version SemVer
---@param req SemVer
---@return boolean
local function matches_exact(version, req)
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

---@param version SemVer
---@param req SemVer
---@return boolean
local function matches_caret(version, req)
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

    return M.compare_pre(version.pre, req.pre) >= 0
end

---@param version SemVer
---@param req SemVer
---@return boolean
local function matches_tilde(version, req)
    if req.major and req.major ~= version.major then
        return false
    end
    if req.minor and req.minor ~= version.minor then
        return false
    end
    if req.patch and req.patch ~= version.patch then
        return version.patch > req.patch
    end

    return M.compare_pre(version.pre, req.pre) >= 0
end

---@param v SemVer
---@param r Requirement
---@return boolean
function M.matches_requirement(v, r)
    if r.cond == Cond.CR or r.cond == Cond.BL then
        return matches_caret(v, r.vers)
    elseif r.cond == Cond.TL then
        return matches_tilde(v, r.vers)
    elseif r.cond == Cond.EQ or r.cond == Cond.WL then
        return matches_exact(v, r.vers)
    elseif r.cond == Cond.LT then
        return matches_less(v, r.vers)
    elseif r.cond == Cond.LE then
        return matches_exact(v, r.vers) or matches_less(v, r.vers)
    elseif r.cond == Cond.GT then
        return matches_greater(v, r.vers)
    else -- if r.cond == Cond.GE then
        return matches_exact(v, r.vers) or matches_greater(v, r.vers)
    end
end

---@param version SemVer
---@param requirements Requirement[]
---@return boolean
function M.matches_requirements(version, requirements)
    for _, r in ipairs(requirements) do
        if not M.matches_requirement(version, r) then
            return false
        end
    end
    return true
end

---Whether the list of requirements allow pre-release versions
---@param reqs Requirement[]
---@return boolean
function M.allows_pre(reqs)
    for _, r in ipairs(reqs) do
        if r.vers.pre then
            return true
        end
    end
    return false
end

return M
