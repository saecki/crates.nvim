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

    -- Open the homepage of the crate on the current line.
    open_homepage: function()
    -- Open the repository page of the crate on the current line.
    open_repository: function()
    -- Open the documentation page of the crate on the current line.
    open_documentation: function()
    -- Open the `crates.io` page of the crate on the current line.
    open_crates_io: function()

    -- Returns whether there is information to show in a popup.
    popup_available: function(): boolean
    -- Show/hide popup with crate details, all versions, all features or details about one feature.
    -- If `c#popup.autofocus` is disabled calling this again will focus the popup.
    show_popup: function()
    -- Same as `f#crates.show_popup()` but always show crate details.
    show_crate_popup: function()
    -- Same as `f#crates.show_popup()` but always show versions.
    show_versions_popup: function()
    -- Same as `f#crates.show_popup()` but always show features or features details.
    show_features_popup: function()
    -- Same as `f#crates.show_popup()` but always show depedencies.
    show_dependencies_popup: function()
    -- Focus the popup (jump into the floating window).
    -- Optionally specify the line to jump to, inside the popup.
    focus_popup: function(line: integer|nil)
    -- Hide the popup.
    hide_popup: function()
end

local actions = require("crates.actions")
local config = require("crates.config")
local Config = config.Config
local core = require("crates.core")
local popup = require("crates.popup")
local state = require("crates.state")
local ui = require("crates.ui")
local util = require("crates.util")

function M.setup(cfg: Config)
    state.cfg = config.build(cfg)

    local group = vim.api.nvim_create_augroup("Crates", {})
    if state.cfg.autoload then
        vim.api.nvim_create_autocmd("BufRead", {
            group = group,
            pattern = "Cargo.toml",
            callback = function()
                M.update()
            end,
        })
    end
    if state.cfg.autoupdate then
        vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
            group = group,
            pattern = "Cargo.toml",
            callback = function()
                M.update()
            end,
        })
    end
    vim.api.nvim_create_autocmd({ "CursorMoved" ,"CursorMovedI" }, {
        group = group,
        pattern = "Cargo.toml",
        callback = function()
            popup.hide()
        end,
    })

    if state.cfg.src.coq.enabled then
        require("crates.src.coq").setup(state.cfg.src.coq.name)
    end

    if state.cfg.null_ls.enabled then
        require("crates.null-ls").setup(state.cfg.null_ls.name)
    end
end

function M.hide()
    state.visible = false
    for b,_ in pairs(state.buf_cache) do
        ui.clear(b)
    end
end

function M.show()
    state.visible = true

    -- make sure we update the current buffer (first)
    local buf = util.current_buf()
    core.update(buf, false)

    for b,_ in pairs(state.buf_cache) do
        if b ~= buf then
            core.update(b, false)
        end
    end
end

function M.toggle()
    if state.visible then
        M.hide()
    else
        M.show()
    end
end

function M.update(buf: integer|nil)
    core.update(buf, false)
end

function M.reload(buf: integer|nil)
    core.update(buf, true)
end

M.upgrade_crate = actions.upgrade_crate
M.upgrade_crates = actions.upgrade_crates
M.upgrade_all_crates = actions.upgrade_all_crates
M.update_crate = actions.update_crate
M.update_crates = actions.update_crates
M.update_all_crates = actions.update_all_crates
M.open_homepage = actions.open_homepage
M.open_repository = actions.open_repository
M.open_documentation = actions.open_documentation
M.open_crates_io = actions.open_crates_io

M.popup_available = popup.available
M.show_popup = popup.show
M.show_crate_popup = popup.show_crate
M.show_versions_popup = popup.show_versions
M.show_features_popup = popup.show_features
M.show_dependencies_popup = popup.show_dependencies
M.focus_popup = popup.focus
M.hide_popup = popup.hide

return M
