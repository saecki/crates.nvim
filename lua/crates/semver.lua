---@class SemVer
---@field major integer
---@field minor integer
---@field patch integer
---@field suffix string
---@field display fun(self:SemVer): string

---@class Requirement
---@field cond string
---@field cond_col Range -- relative to to the start of the requirement text
---@field vers SemVer
---@field vers_col Range -- relative to to the start of the requirement text

local M = {}

local Range = require('crates.types').Range

M.SemVer = {}
local SemVer = M.SemVer

---@param obj table
---@return SemVer
function SemVer.new(obj)
    return setmetatable(obj, { __index = SemVer })
end

---@param self SemVer
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

    if self.suffix then
        text = text .. "-" .. self.suffix
    end

    return text
end

---@param str string
---@return SemVer
function M.parse_version(str)
    local major, minor, patch, suffix

    major, minor, patch, suffix = str:match("^([0-9]+)%.([0-9]+)%.([0-9]+)-([^%s]+)$")
    if major and minor and patch and suffix then
        return SemVer.new {
            major = tonumber(major),
            minor = tonumber(minor),
            patch = tonumber(patch),
            suffix = suffix,
        }
    end

    major, minor, patch = str:match("^([0-9]+)%.([0-9]+)%.([0-9]+)$")
    if major and minor and patch then
        return SemVer.new {
            major = tonumber(major),
            minor = tonumber(minor),
            patch = tonumber(patch),
        }
    end

    major, minor = str:match("^([0-9]+)%.([0-9]+)[%.]?$")
    if major and minor then
        return SemVer.new {
            major = tonumber(major),
            minor = tonumber(minor),
        }
    end

    major = str:match("^([0-9]+)[%.]?$")
    if major then
        return SemVer.new { major = tonumber(major) }
    end

    return SemVer.new {}
end

---@param str string
---@return Requirement
function M.parse_requirement(str)
    local vs, vers_str, ve, re

    vs, vers_str, ve = str:match("^=%s*()(.+)()$")
    if vs and vers_str and ve then
        return {
            cond = "eq",
            cond_col = Range.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Range.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^<=%s*()(.+)()$")
    if vs and vers_str and ve then
        return {
            cond = "le",
            cond_col = Range.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Range.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^<%s*()(.+)()$")
    if vs and vers_str and ve then
        return {
            cond = "lt",
            cond_col = Range.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Range.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^>=%s*()(.+)()$")
    if vs and vers_str and ve then
        return {
            cond = "ge",
            cond_col = Range.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Range.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^>%s*()(.+)()$")
    if vs and vers_str and ve then
        return {
            cond = "gt",
            cond_col = Range.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Range.new(vs - 1, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^%~%s*()(.+)()$")
    if vs and vers_str and ve then
        return {
            cond = "tl",
            cond_col = Range.new(0, vs - 1),
            vers = M.parse_version(vers_str),
            vers_col = Range.new(vs - 1, ve - 1),
        }
    end

    vers_str, ve, re = str:match("^(.+)()%.%*()$")
    if vers_str and ve and re then
        return {
            cond = "wl",
            cond_col = Range.new(ve - 1, re - 1),
            vers = M.parse_version(vers_str),
            vers_col = Range.new(0, ve - 1),
        }
    end

    vs, vers_str, ve = str:match("^%^%s*()(.+)()$")
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

---@param str string
---@return Requirement[]
function M.parse_requirements(str)
    local requirements = {}
    for s, r  in str:gmatch("[,]?%s*()([^,]+)%s*[,]?") do
        local requirement = M.parse_requirement(r)
        requirement.vers_col.s = requirement.vers_col.s + s - 1
        requirement.vers_col.e = requirement.vers_col.e + s - 1
        table.insert(requirements, requirement)
    end

    return requirements
end

---@param version SemVer
---@return SemVer
local function filled_zeros(version)
    return {
        major = version.major or 0,
        minor = version.minor or 0,
        patch = version.patch or 0,
        suffix = version.suffix,
    }
end

---@param a string
---@param b string
---@return integer
local function compare_suffixes(a, b)
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

---@param a SemVer
---@param b SemVer
---@return integer
local function compare_versions(a, b)
    local major = a.major - b.major
    local minor = a.minor - b.minor
    local patch = a.patch - b.patch
    local suffix = compare_suffixes(a.suffix, b.suffix)

    if major == 0 then
        if minor == 0 then
            if patch == 0 then
                return suffix
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

---@param v SemVer
---@param r Requirement
---@return boolean
function M.matches_requirement(v, r)
    if r.cond == "cr" or r.cond == "bl" then
        if r.vers.major == v.major and not r.vers.minor then
            return true
        end

        local a = filled_zeros(v)
        local b = filled_zeros(r.vers)
        local c
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
        local c
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
        return r.vers.suffix == v.suffix
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

return M
