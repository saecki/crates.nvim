---@class SemVer
---@field major integer
---@field minor integer
---@field patch integer
---@field suffix string

---@class Requirement
---@field cond string
---@field vers SemVer

local M = {}

---@param string string
---@return SemVer
function M.parse_version(string)
    local major, minor, patch, suffix

    major, minor, patch, suffix = string:match("^([0-9]+)%.([0-9]+)%.([0-9]+)([^%s]*)$")
    if major and minor and patch and suffix and suffix ~= "" then
        return {
            major = tonumber(major),
            minor = tonumber(minor),
            patch = tonumber(patch),
            suffix = suffix,
        }
    end

    major, minor, patch = string:match("^([0-9]+)%.([0-9]+)%.([0-9]+)$")
    if major and minor and patch then
        return {
            major = tonumber(major),
            minor = tonumber(minor),
            patch = tonumber(patch),
        }
    end

    major, minor = string:match("^([0-9]+)%.([0-9]+)")
    if major and minor then
        return {
            major = tonumber(major),
            minor = tonumber(minor),
        }
    end

    major = string:match("^([0-9]+)")
    if major then
        return { major = tonumber(major) }
    end

    return {}
end

---@param string string
---@return Requirement
function M.parse_requirement(string)
    local vers_str

    vers_str = string:match("^=(.+)$")
    if vers_str then
        return { cond = "eq", vers = M.parse_version(vers_str) }
    end

    vers_str = string:match("^<=(.+)$")
    if vers_str then
        return { cond = "le", vers = M.parse_version(vers_str) }
    end

    vers_str = string:match("^<(.+)$")
    if vers_str then
        return { cond = "lt", vers = M.parse_version(vers_str) }
    end

    vers_str = string:match("^>=(.+)$")
    if vers_str then
        return { cond = "ge", vers = M.parse_version(vers_str) }
    end

    vers_str = string:match("^>(.+)$")
    if vers_str then
        return { cond = "gt", vers = M.parse_version(vers_str) }
    end

    vers_str = string:match("^%~(.+)$")
    if vers_str then
        return { cond = "tl", vers = M.parse_version(vers_str) }
    end

    vers_str = string:match("^(.+)%.%*$")
    if vers_str then
        return { cond = "tl", vers = M.parse_version(vers_str) }
    end

    vers_str = string:match("^%^(.+)$")
    if vers_str then
        return { cond = "cr", vers = M.parse_version(vers_str) }
    end

    return { cond = "cr", vers = M.parse_version(string) }
end

---@param string string
---@return Requirement[]
function M.parse_requirements(string)
    local requirements = {}
    for c in string:gmatch("[,]?%s*([^,]+)%s*[,]?") do
        local requirement = M.parse_requirement(c)
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
    if r.cond == "cr" then
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

    if r.cond == "eq" then
        return v.major == r.vers.major
            and v.minor == r.vers.minor
            and v.patch == r.vers.patch
            and v.suffix == r.vers.suffix
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
    local matches = true
    for _,r in ipairs(requirements) do
        matches = matches and M.matches_requirement(version, r)
    end
    return matches
end

return M
