local M = {}

local api = require('crates.api')
local config = require('crates.config')
local core = require('crates.core')
local popup = require('crates.popup')
local semver = require('crates.semver')
local toml = require('crates.toml')
local util = require('crates.util')
local Range = require('crates.types').Range

---@param buf integer
---@param crate Crate
---@param versions Version[]
function M.display_versions(buf, crate, versions)
    if not core.visible or not crate.reqs then
        vim.api.nvim_buf_clear_namespace(buf, M.namespace_id, crate.lines.s, crate.lines.e)
        return
    end

    local avoid_pre = core.cfg.avoid_prerelease and not crate.req_has_suffix
    local newest, newest_pre, newest_yanked = util.get_newest(versions, avoid_pre, nil)
    newest = newest or newest_pre or newest_yanked

    local virt_text
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

---@param buf integer
---@param crate Crate
function M.display_loading(buf, crate)
    local virt_text = { { core.cfg.text.loading, core.cfg.highlight.loading } }
    vim.api.nvim_buf_clear_namespace(buf, M.namespace_id, crate.lines.s, crate.lines.e)
    vim.api.nvim_buf_set_virtual_text(buf, M.namespace_id, crate.lines.s, virt_text, {})
end

---@param crate Crate
function M.reload_crate(crate)
    local function on_fetched(versions)
        if versions and versions[1] then
            core.vers_cache[crate.name] = versions
        end

        for buf,crates in pairs(core.crate_cache) do
            local c = crates[crate.name]

            -- only update loaded buffers
            if c and vim.api.nvim_buf_is_loaded(buf) then
                M.display_versions(buf, c, versions)
            end
        end
    end

    if core.cfg.loading_indicator then
        M.display_loading(0, crate)
    end

    api.fetch_crate_versions(crate.name, on_fetched)
end

function M.clear()
    if M.namespace_id then
        vim.api.nvim_buf_clear_namespace(0, M.namespace_id, 0, -1)
    end
    M.namespace_id = vim.api.nvim_create_namespace("crates.nvim")
end

function M.hide()
    core.visible = false
    M.clear()
end

function M.reload()
    core.visible = true
    core.vers_cache = {}
    M.clear()

    local cur_buf = util.current_buf()
    local crates = toml.parse_crates(0)

    core.crate_cache[cur_buf] = {}

    for _,c in ipairs(crates) do
        core.crate_cache[cur_buf][c.name] = c
        M.reload_crate(c)
    end
end

function M.update()
    core.visible = true
    M.clear()

    local cur_buf = util.current_buf()
    local crates = toml.parse_crates(0)

    core.crate_cache[cur_buf] = {}

    for _,c in ipairs(crates) do
        local versions = core.vers_cache[c.name]

        core.crate_cache[cur_buf][c.name] = c

        if versions then
            M.display_versions(0, c, versions)
        else
            M.reload_crate(c)
        end
    end
end

function M.toggle()
    if core.visible then
        M.hide()
    else
        M.update()
    end
end

--- upgrade the crate on the current line
---@param smart boolean | nil
function M.upgrade_crate(smart)
    local linenr = vim.api.nvim_win_get_cursor(0)[1]
    util.upgrade_crates(Range.new(linenr - 1, linenr ), smart)
end

--- upgrade the crates on the lines visually selected
---@param smart boolean | nil
function M.upgrade_crates(smart)
    local lines = Range.new(
        vim.api.nvim_buf_get_mark(0, "<")[1] - 1,
        vim.api.nvim_buf_get_mark(0, ">")[1]
    )
    util.upgrade_crates(lines, smart)
end

--- upgrade all crates in the buffer
---@param smart boolean | nil
function M.upgrade_all_crates(smart)
    local lines = Range.new(0, vim.api.nvim_buf_line_count(0))
    util.upgrade_crates(lines, smart)
end

-- update the crate on the current line
---@param smart boolean | nil
function M.update_crate(smart)
    local linenr = vim.api.nvim_win_get_cursor(0)[1]
    util.update_crates(Range.new(linenr - 1, linenr), smart)
end

-- update the crates on the lines visually selected
---@param smart boolean | nil
function M.update_crates(smart)
    local lines = Range.new(
        vim.api.nvim_buf_get_mark(0, "<")[1] - 1,
        vim.api.nvim_buf_get_mark(0, ">")[1]
    )
    util.update_crates(lines, smart)
end

--- update all crates in the buffer
---@param smart boolean | nil
function M.update_all_crates(smart)
    local lines = Range.new(0, vim.api.nvim_buf_line_count(0))
    util.update_crates(lines, smart)
end


---@param cfg Config
function M.setup(cfg)
    local default = config.default()
    if cfg then
        core.cfg = vim.tbl_deep_extend("keep", cfg, default)
    else
        core.cfg = vim.tbl_deep_extend("keep", core.cfg, default)
    end

    vim.cmd("augroup Crates")
    vim.cmd("autocmd!")
    if core.cfg.autoload then
        vim.cmd("autocmd BufRead Cargo.toml lua require('crates').update()")
    end
    if core.cfg.autoupdate then
        vim.cmd("autocmd TextChanged,TextChangedI,TextChangedP Cargo.toml lua require('crates').update()")
    end
    vim.cmd("augroup END")

    vim.cmd([[
        augroup CratesPopup
        autocmd!
        autocmd CursorMoved,CursorMovedI Cargo.toml lua require('crates.popup').hide()
        augroup END
    ]])
end

M.show_popup = popup.show
M.hide_popup = popup.hide

return M
