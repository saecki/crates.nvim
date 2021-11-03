local record M
    namespace_id: integer
end

local core = require('crates.core')
local semver = require('crates.semver')
local util = require('crates.util')
local Crate = require('crates.toml').Crate
local Version = require('crates.api').Version

function M.display_versions(buf: integer, crate: Crate, versions: {Version})
    if not core.visible or not crate.reqs then
        vim.api.nvim_buf_clear_namespace(buf, M.namespace_id, crate.lines.s, crate.lines.e)
        return
    end

    local avoid_pre = core.cfg.avoid_prerelease and not crate.req_has_suffix
    local newest, newest_pre, newest_yanked = util.get_newest(versions, avoid_pre, nil)
    newest = newest or newest_pre or newest_yanked

    local virt_text: {{string, string}}
    if newest then
        if semver.matches_requirements(newest.parsed, crate.reqs) then
            -- version matches, no upgrade available
            virt_text = { { string.format(core.cfg.text.version, newest.num), core.cfg.highlight.version } }
        else
            -- version does not match, upgrade available
            local match, match_pre, match_yanked = util.get_newest(versions, avoid_pre, crate.reqs)

            local upgrade_text = { string.format(core.cfg.text.upgrade, newest.num), core.cfg.highlight.upgrade }

            if match then
                -- found a match
                virt_text = {
                    { string.format(core.cfg.text.version, match.num), core.cfg.highlight.version },
                    upgrade_text,
                }
            elseif match_pre then
                -- found a pre-release match
                virt_text = {
                    { string.format(core.cfg.text.prerelease, match_pre.num), core.cfg.highlight.prerelease },
                    upgrade_text,
                }
            elseif match_yanked then
                -- found a yanked match
                virt_text = {
                    { string.format(core.cfg.text.yanked, match_yanked.num), core.cfg.highlight.yanked },
                    upgrade_text,
                }
            else
                -- no match found
                virt_text = {
                    { core.cfg.text.nomatch, core.cfg.highlight.nomatch },
                    upgrade_text,
                }
            end
        end
    else
        virt_text = { { core.cfg.text.error, core.cfg.highlight.error } }
    end

    vim.api.nvim_buf_clear_namespace(buf, M.namespace_id, crate.lines.s, crate.lines.e)
    vim.api.nvim_buf_set_virtual_text(buf, M.namespace_id, crate.req_line, virt_text, {})
end

function M.display_loading(buf: integer, crate: Crate)
    local virt_text = { { core.cfg.text.loading, core.cfg.highlight.loading } }
    vim.api.nvim_buf_clear_namespace(buf, M.namespace_id, crate.lines.s, crate.lines.e)
    vim.api.nvim_buf_set_virtual_text(buf, M.namespace_id, crate.lines.s, virt_text, {})
end

function M.clear()
    if M.namespace_id then
        vim.api.nvim_buf_clear_namespace(0, M.namespace_id, 0, -1)
    end
    M.namespace_id = vim.api.nvim_create_namespace("crates.nvim") as integer
end

return M
