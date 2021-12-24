local record M
    -- Setup config and auto commands.
    setup: function(cfg: Config)

    -- Disable UI elements (virtual text and diagnostics).
    hide: function()
    -- Enable UI elements (virtual text and diagnostics).
    show: function()
    -- Enable or disable UI elements (virtual text and diagnostics).
    toggle: function()
    -- Update data. Optionally specify which `p#buf` to update.
    update: function(buf: integer|nil)
    -- Reload data (clears cache). Optionally specify which `p#buf` to reload.
    reload: function(buf: integer|nil)

    -- Upgrade the crate on the current line.
    -- If the `p#alt` flag is passed as true, the opposite of the `c#smart_insert` config
    -- option will be used to insert the version.
    upgrade_crate: function(alt: boolean|nil)
    -- Upgrade the crates on the lines visually selected.
    -- See `f#crates.upgrade_crate()`.
    upgrade_crates: function(alt: boolean|nil)
    -- Upgrade all crates in the buffer.
    -- See `f#crates.upgrade_crate()`.
    upgrade_all_crates: function(alt: boolean|nil)

    -- Update the crate on the current line.
    -- See `f#crates.upgrade_crate()`.
    update_crate: function(alt: boolean|nil)
    -- Update the crates on the lines visually selected.
    -- See `f#crates.upgrade_crate()`.
    update_crates: function(alt: boolean|nil)
    -- Update all crates in the buffer.
    -- See `f#crates.upgrade_crate()`.
    update_all_crates: function(alt: boolean|nil)

    -- Show/hide popup with all versions, all features or details about one feature.
    -- If `c#popup.autofocus` is disabled calling this again will focus the popup.
    show_popup: function()
    -- Same as `f#crates.show_popup()` but always show versions.
    show_versions_popup: function()
    -- Same as `f#crates.show_popup()` but always show features or features details.
    show_features_popup: function()
    -- Focus the popup (jump into the floating window).
    -- Optionally specify the line to jump to, inside the popup.
    focus_popup: function(line: integer|nil)
    -- Hide the popup.
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
local diagnostic = require('crates.diagnostic')
local util = require('crates.util')
local ui = require('crates.ui')
local Range = require('crates.types').Range

local function reload_crate(buf: integer, crate: Crate)
    local function on_fetched(versions: {Version})
        if versions and versions[1] then
            core.vers_cache[crate.name] = versions
        end

        for b,crates in pairs(core.crate_cache) do
            local c = crates[crate.name]

            if c and vim.api.nvim_buf_is_loaded(b) then
                local info = diagnostic.process_crate_versions(c, versions)
                ui.display_crate_info(b, info)
            end
        end
    end

    if core.cfg.loading_indicator then
        ui.display_loading(buf, crate)
    end

    api.fetch_crate_versions(crate.name, on_fetched)
end

local function update(buf: integer|nil, reload: boolean)
    if reload then
        core.vers_cache = {}
    end

    buf = buf or util.current_buf()
    local crates = toml.parse_crates(buf)
    local cache, diagnostics = diagnostic.process_crates(crates)

    ui.clear(buf)
    ui.display_diagnostics(buf, diagnostics)
    for _,c in pairs(cache) do
        local versions = core.vers_cache[c.name]

        if not reload and versions then
            local info = diagnostic.process_crate_versions(c, versions)
            ui.display_crate_info(buf, info)
        else
            reload_crate(buf, c)
        end
    end

    core.crate_cache[buf] = cache
end

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

function M.hide()
    core.visible = false
    for b,_ in pairs(core.crate_cache) do
        ui.clear(b)
    end
end

function M.show()
    core.visible = true

    -- make sure we update the current buffer (first)
    local buf = util.current_buf()
    update(buf, false)

    for b,_ in pairs(core.crate_cache) do
        if b ~= buf then
            update(b, false)
        end
    end
end

function M.toggle()
    if core.visible then
        M.hide()
    else
        M.show()
    end
end

function M.update(buf: integer|nil)
    update(buf, false)
end

function M.reload(buf: integer|nil)
    update(buf, true)
end


function M.upgrade_crate(alt: boolean|nil)
    local linenr = vim.api.nvim_win_get_cursor(0)[1] as integer
    local crates = util.get_lines_crates(Range.pos(linenr - 1))
    util.upgrade_crates(crates, alt)
end

function M.upgrade_crates(alt: boolean|nil)
    local lines = Range.new(
        vim.api.nvim_buf_get_mark(0, "<")[1] as integer - 1,
        vim.api.nvim_buf_get_mark(0, ">")[1] as integer
    )
    local crates = util.get_lines_crates(lines)
    util.upgrade_crates(crates, alt)
end

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

function M.update_crate(alt: boolean|nil)
    local linenr = vim.api.nvim_win_get_cursor(0)[1] as integer
    local crates = util.get_lines_crates(Range.pos(linenr - 1))
    util.update_crates(crates, alt)
end

function M.update_crates(alt: boolean|nil)
    local lines = Range.new(
        vim.api.nvim_buf_get_mark(0, "<")[1] as integer - 1,
        vim.api.nvim_buf_get_mark(0, ">")[1] as integer
    )
    local crates = util.get_lines_crates(lines)
    util.update_crates(crates, alt)
end

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

M.show_popup = popup.show
M.show_versions_popup = popup.show_versions
M.show_features_popup = popup.show_features
M.focus_popup = popup.focus
M.hide_popup = popup.hide

return M
