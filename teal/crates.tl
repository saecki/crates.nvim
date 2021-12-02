local record M
    show_popup: function()
    show_versions_popup: function()
    show_features_popup: function()
    focus_popup: function(integer|nil)
    hide_popup: function()
end

local api = require('crates.api')
local Version = api.Version
local config = require('crates.config')
local Config = config.Config
local core = require('crates.core')
local popup = require('crates.popup')
local toml = require('crates.toml')
local Crate = toml.Crate
local util = require('crates.util')
local ui = require('crates.ui')
local Range = require('crates.types').Range

local function reload_crate(crate: Crate)
    local function on_fetched(versions: {Version})
        if versions and versions[1] then
            core.vers_cache[crate.name] = versions
        end

        for buf,crates in pairs(core.crate_cache) do
            local c = crates[crate.name]

            -- only update loaded buffers
            if c and vim.api.nvim_buf_is_loaded(buf) then
                ui.display_versions(buf, c, versions)
            end
        end
    end

    if core.cfg.loading_indicator then
        ui.display_loading(0, crate)
    end

    api.fetch_crate_versions(crate.name, on_fetched)
end

-- Hide virtual text.
function M.hide()
    core.visible = false
    ui.clear()
end

-- Force-reload and display virtual text (clears cache).
function M.reload()
    core.visible = true
    core.vers_cache = {}
    ui.clear()

    local cur_buf = util.current_buf()
    local crates = toml.parse_crates(0)

    core.crate_cache[cur_buf] = {}

    for _,c in ipairs(crates) do
        core.crate_cache[cur_buf][c.name] = c
        reload_crate(c)
    end
end

-- Load and display virtual text.
function M.update()
    core.visible = true
    ui.clear()

    local cur_buf = util.current_buf()
    local crates = toml.parse_crates(0)

    core.crate_cache[cur_buf] = {}

    for _,c in ipairs(crates) do
        local versions = core.vers_cache[c.name]

        core.crate_cache[cur_buf][c.name] = c

        if versions then
            ui.display_versions(0, c, versions)
        else
            reload_crate(c)
        end
    end
end

-- Show or hide virtual text.
function M.toggle()
    if core.visible then
        M.hide()
    else
        M.update()
    end
end


-- Upgrade the crate on the current line.
function M.upgrade_crate(alt: boolean|nil)
    local linenr = vim.api.nvim_win_get_cursor(0)[1] as integer
    local crates = util.get_lines_crates(Range.pos(linenr - 1))
    util.upgrade_crates(crates, alt)
end

-- Upgrade the crates on the lines visually selected.
function M.upgrade_crates(alt: boolean|nil)
    local lines = Range.new(
        vim.api.nvim_buf_get_mark(0, "<")[1] as integer - 1,
        vim.api.nvim_buf_get_mark(0, ">")[1] as integer
    )
    local crates = util.get_lines_crates(lines)
    util.upgrade_crates(crates, alt)
end

-- Upgrade all crates in the buffer.
function M.upgrade_all_crates(alt: boolean|nil)
    local cur_buf = util.current_buf()
    local crates = core.crate_cache[cur_buf]
    if not crates then return end

    local crate_versions = {}
    for _,c in pairs(crates) do
        table.insert(crate_versions, {
            crate = c,
            versions = core.vers_cache[c.name]
        })
    end

    util.upgrade_crates(crate_versions, alt)
end

-- Update the crate on the current line.
function M.update_crate(alt: boolean|nil)
    local linenr = vim.api.nvim_win_get_cursor(0)[1] as integer
    local crates = util.get_lines_crates(Range.pos(linenr - 1))
    util.update_crates(crates, alt)
end

-- Update the crates on the lines visually selected.
function M.update_crates(alt: boolean|nil)
    local lines = Range.new(
        vim.api.nvim_buf_get_mark(0, "<")[1] as integer - 1,
        vim.api.nvim_buf_get_mark(0, ">")[1] as integer
    )
    local crates = util.get_lines_crates(lines)
    util.update_crates(crates, alt)
end

-- Update all crates in the buffer>
function M.update_all_crates(alt: boolean|nil)
    local cur_buf = util.current_buf()
    local crates = core.crate_cache[cur_buf]
    if not crates then return end

    local crate_versions = {}
    for _,c in pairs(crates) do
        table.insert(crate_versions, {
            crate = c,
            versions = core.vers_cache[c.name]
        })
    end

    util.update_crates(crate_versions, alt)
end

-- Setup config and auto commands.
function M.setup(cfg: Config)
    core.cfg = config.build(cfg)

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

-- Show/hide popup with all versions or features.
-- If `popup.autofocus` is disabled calling this again will focus the popup.
M.show_popup = popup.show

-- Same as `show_popup` but always show versions.
M.show_versions_popup = popup.show_versions

-- Same as `show_popup` but always show features.
M.show_features_popup = popup.show_features

-- Focus the popup (jump into the floating window).
M.focus_popup = popup.focus

-- Hide the popup.
M.hide_popup = popup.hide

return M
