local M = {}

local core = require('crates.core')
local semver = require('crates.semver')

function M.current_buf()
    return vim.api.nvim_get_current_buf()
end

function M.get_line_crate(linenr)
    local crate = nil

    local cur_buf = M.current_buf()
    local crates = core.crate_cache[cur_buf]
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

function M.get_newest(versions, avoid_pre, reqs)
    if not versions then
        return nil
    end

    local newest_yanked = nil
    local newest_pre = nil
    local newest = nil

    for _,v in ipairs(versions) do
        if not reqs or reqs and semver.matches_requirements(v.parsed, reqs) then
            if not v.yanked then
                if avoid_pre then
                    if v.parsed.suffix then
                        newest_pre = newest_pre or v
                    else
                        newest = v
                        break
                    end
                else
                    newest = v
                    break
                end
            else
                newest_yanked = newest_yanked or v
            end
        end
    end

    return newest, newest_pre, newest_yanked
end

function M.set_version(buf, crate, text)
    vim.api.nvim_buf_set_text(
        buf,
        crate.linenr - 1,
        crate.col[1],
        crate.linenr - 1,
        crate.col[2],
        { text }
    )
end

return M
