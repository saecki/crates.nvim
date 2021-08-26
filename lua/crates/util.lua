local M = {}

local core = require('crates.core')

function M.get_filepath()
    return vim.fn.expand("%:p")
end

function M.get_line_crate(linenr)
    local crate = nil

    local filepath = M.get_filepath()
    local crates = core.crate_cache[filepath]
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

    return crate, core.vers_cache[crate.name]
end

function M.get_newest(versions, avoid_pre)
    if not versions then
        return nil
    end

    local newest_yanked = nil
    local newest_pre = nil

    for _,v in ipairs(versions) do
        if not v.yanked then
            if avoid_pre then
                if v.parsed.suffix then
                    newest_pre = newest_pre or v
                else
                    return v
                end
            else
                return v
            end
        else
            newest_yanked = newest_yanked or v
        end
    end

    return newest_pre or newest_yanked
end

return M
