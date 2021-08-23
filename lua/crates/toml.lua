local M = {}

local function parse_crate_dep_section_line(line)
    local version = line:match("^%s*version%s*=%s*\"(.+)\"%s*$")
    if version then
        return { version = version }
    end

    return nil
end

local function parse_dep_section_line(line)
    -- plain version
    local name, version = line:match("^%s*([^%s]+)%s*=%s*%\"(.+)\"%s*$")
    if name and version then
        return { name = name, version = version }
    end

    -- version in map
    local name, keys = line:match("^%s*([^%s]+)%s*=%s*{(.+)}%s*$")
    if name and keys then
        for val in keys:gmatch("[,]?([^,]+)[,]?") do
            local crate = parse_crate_dep_section_line(val)
            if crate then
                crate.name = name
                return crate
            end
        end
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
                crate.linenr = i - 1
                table.insert(crates, crate)
            end
        elseif dep_section then
            local crate = parse_dep_section_line(l)
            if crate then
                crate.linenr = i - 1
                table.insert(crates, crate)
            end
        end
    end

    return crates
end

return M
