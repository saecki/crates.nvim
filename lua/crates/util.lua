local M = {}

local C = require('crates')

function M.get_line_versions(linenr)
    local crate = nil

    local filepath = C.get_filepath()
    local crates = C.crate_cache[filepath]
    if crates then
        for _,c in pairs(crates) do
            if c.linenr == linenr then
                crate = c
                break
            end
        end
    end

    if not crate then
        return nil, nil
    end

    return crate, C.vers_cache[crate.name]
end

return M
