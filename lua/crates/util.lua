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

function M.upgrade()
    local linenr = vim.api.nvim_win_get_cursor(0)[1]
    local crate, versions = M.get_line_versions(linenr)

    if not crate or not versions then
        return
    end

    local avoid_pre = C.config.avoid_prerelease and not crate.req_has_suffix
    local newest = C.get_newest(crate, versions, avoid_pre)

    if not newest then
        return
    end

    vim.api.nvim_buf_set_text(
        0,
        crate.linenr - 1,
        crate.col[1],
        crate.linenr - 1,
        crate.col[2],
        { newest.num }
    )
end

return M
