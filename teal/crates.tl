local record M
    show_popup: function()
    show_versions_popup: function()
    show_features_popup: function()
    focus_popup: function(integer|nil)
    hide_popup: function()
end

local api = require('crates.api')
local Version = api.Version
local Config = require('crates.config')
local core = require('crates.core')
local popup = require('crates.popup')
local toml = require('crates.toml')
local Crate = toml.Crate
local util = require('crates.util')
local ui = require('crates.ui')
local Range = require('crates.types').Range

function M.reload_crate(crate: Crate)
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

function M.hide()
    core.visible = false
    ui.clear()
end

function M.reload()
    core.visible = true
    core.vers_cache = {}
    ui.clear()

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
function M.upgrade_crate(smart: boolean|nil)
    local linenr = vim.api.nvim_win_get_cursor(0)[1] as integer
    local crates = util.get_lines_crates(Range.pos(linenr - 1))
    util.upgrade_crates(crates, smart)
end

--- upgrade the crates on the lines visually selected
function M.upgrade_crates(smart: boolean|nil)
    local lines = Range.new(
        vim.api.nvim_buf_get_mark(0, "<")[1] as integer - 1,
        vim.api.nvim_buf_get_mark(0, ">")[1] as integer
    )
    local crates = util.get_lines_crates(lines)
    util.upgrade_crates(crates, smart)
end

--- upgrade all crates in the buffer
function M.upgrade_all_crates(smart: boolean|nil)
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

    util.upgrade_crates(crate_versions, smart)
end

-- update the crate on the current line
function M.update_crate(smart: boolean|nil)
    local linenr = vim.api.nvim_win_get_cursor(0)[1] as integer
    local crates = util.get_lines_crates(Range.pos(linenr - 1))
    util.update_crates(crates, smart)
end

-- update the crates on the lines visually selected
function M.update_crates(smart: boolean|nil)
    local lines = Range.new(
        vim.api.nvim_buf_get_mark(0, "<")[1] as integer - 1,
        vim.api.nvim_buf_get_mark(0, ">")[1] as integer
    )
    local crates = util.get_lines_crates(lines)
    util.update_crates(crates, smart)
end

--- update all crates in the buffer
function M.update_all_crates(smart: boolean|nil)
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

    util.update_crates(crate_versions, smart)
end


function M.setup(cfg: Config)
    local default = Config.default()
    if cfg then
        core.cfg = vim.tbl_deep_extend("keep", cfg as table, default as table) as Config
    else
        core.cfg = vim.tbl_deep_extend("keep", core.cfg as table, default as table) as Config
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
M.show_versions_popup = popup.show_versions
M.show_features_popup = popup.show_features
M.focus_popup = popup.focus
M.hide_popup = popup.hide

return M
