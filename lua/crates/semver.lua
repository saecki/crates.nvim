local types = require("crates.types")
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
        return SemVer.new {
            major = tonumber(major),
            minor = tonumber(minor),
            patch = tonumber(patch),
            meta = meta,
        }
    end

    major, minor, patch = str:match("^([0-9]+)%.([0-9]+)%.([0-9]+)$")
    if major then
        return SemVer.new {
            major = tonumber(major),
            minor = tonumber(minor),
            patch = tonumber(patch),
        }
    end

    major, minor = str:match("^([0-9]+)%.([0-9]+)[%.]?$")
    if major then
        return SemVer.new {
            major = tonumber(major),
            minor = tonumber(minor),
        }
    end

    major = str:match("^([0-9]+)[%.]?$")
    if major then
        return SemVer.new {
            major = tonumber(major),
        }
    end

    return SemVer.new {}
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
            cond = "eq",
            cond_col = Span.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Span.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^<=%s*()(.+)()$")
    if vs and vers_str and ve then
        ---@type Requirement
        return {
            cond = "le",
            cond_col = Span.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Span.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^<%s*()(.+)()$")
    if vs and vers_str and ve then
        ---@type Requirement
        return {
            cond = "lt",
            cond_col = Span.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Span.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^>=%s*()(.+)()$")
    if vs and vers_str and ve then
        ---@type Requirement
        return {
            cond = "ge",
            cond_col = Span.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Span.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^>%s*()(.+)()$")
    if vs and vers_str and ve then
        ---@type Requirement
        return {
            cond = "gt",
            cond_col = Span.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Span.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^%~%s*()(.+)()$")
    if vs and vers_str and ve then
        ---@type Requirement
        return {
            cond = "tl",
            cond_col = Span.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Span.new(vs - 1, ve - 1),
        }
    end

    local wl = str:match("^%*$")
    if wl then
        ---@type Requirement
        return {
            cond = "wl",
            cond_col = Span.new(0, 1),
            vers = SemVer.new {},
            vers_col = Span.new(0, 0),
        }
    end

    vers_str, rs, re = str:match("^(.+)()%.%*()$")
    if vers_str and rs and re then
        ---@type Requirement
        return {
            cond = "wl",
            cond_col = Span.new(rs - 1, re - 1),
            vers = M.parse_version(vers_str),
            vers_col = Span.new(0, rs - 1),
        }
    end

    vs, vers_str, ve = str:match("^%^%s*()(.+)()$")
    if vs and vers_str and ve then
        ---@type Requirement
        return {
            cond = "cr",
            cond_col = Span.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Span.new(vs - 1, ve - 1),
        }
    end

    ---@type Requirement
    return {
        cond = "bl",
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
    for s, r  in str:gmatch("[,]?%s*()([^,]+)%s*[,]?") do
        local requirement = M.parse_requirement(r)
        requirement.vers_col.s = requirement.vers_col.s + s - 1
        requirement.vers_col.e = requirement.vers_col.e + s - 1
        table.insert(requirements, requirement)
    end

    return requirements
end

---@param version string
---@param req string
---@return integer
local function compare_pre(version, req)
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

    return compare_pre(version.pre, req.pre) < 0
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

    return compare_pre(version.pre, req.pre) > 0
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

    return compare_pre(version.pre, req.pre) >= 0
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

    return compare_pre(version.pre, req.pre) >= 0
end

---@param v SemVer
---@param r Requirement
---@return boolean
function M.matches_requirement(v, r)
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

---@param version SemVer
---@param requirements Requirement[]
---@return boolean
function M.matches_requirements(version, requirements)
    for _,r in ipairs(requirements) do
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
    for _,r in ipairs(reqs) do
        if r.vers.pre then
            return true
        end
    end
    return false
end

return M
