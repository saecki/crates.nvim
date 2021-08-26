local M = {}

local semver = require('crates.semver')

local function parse_crate_dep_section_line(line)
    local vs, version, ve = line:match([[^%s*version%s*=%s*["']()([^"']*)()["']?%s*$]])
    if version and vs and ve then
        return { version = version, col = { vs - 1, ve - 1 } }
    end

    return nil
end

local function parse_dep_section_line(line)
    local name, version, vs, ve
    -- plain version
    name, vs, version, ve = line:match([[^%s*([^%s]+)%s*=%s*["']()([^"']*)()["']?%s*$]])
    if name and version and vs and ve then
        return { name = name, version = version, col = { vs - 1, ve - 1 } }
    end

    -- version in map
    local pat = [[^%s*([^%s]+)%s*=%s*{.*[,]?%s*version%s*=%s*["']()([^"']*)()["']?%s*[,]?.*[}]?%s*$]]
    name, vs, version, ve = line:match(pat)
    if name and version and vs and ve then
        return { name = name, version = version, col = { vs - 1, ve - 1 } }
    end

    return nil
end

function M.parse_crates()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    local crates = {}
    local dep_section = false
    local dep_section_crate = nil -- [dependencies.<crate>]

    for i,l in ipairs(lines) do
        local uncommented = l:match("^([^#]*)#.*$")
        if uncommented then
            l = uncommented
        end

        local section = l:match("^%s*%[(.+)%]%s*$")

        if section then
            local c = section:match("^.*dependencies(.*)$")
            if c then
                dep_section = true
                dep_section_crate = c:match("^%.(.+)$")
            else
                dep_section = false
                dep_section_crate = nil
            end
        elseif dep_section and dep_section_crate then
            local crate = parse_crate_dep_section_line(l)
            if crate then
                crate.name = dep_section_crate
                crate.linenr = i
                table.insert(crates, crate)
            end
        elseif dep_section then
            local crate = parse_dep_section_line(l)
            if crate then
                crate.linenr = i
                table.insert(crates, crate)
            end
        end
    end

    for _,c in ipairs(crates) do
        c.reqs = semver.parse_requirements(c.version)
        print(vim.inspect(c.requirements))

        c.req_has_suffix = false
        for _,r in ipairs(c.reqs) do
            if r.vers.suffix then
                c.req_has_suffix = true
                break
            end
        end
    end

    return crates
end

return M
