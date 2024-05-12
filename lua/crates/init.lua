local actions = require("crates.actions")
local async = require("crates.async")
local command = require("crates.command")
local config = require("crates.config")
local core = require("crates.core")
local highlight = require("crates.highlight")
local popup = require("crates.popup")
local state = require("crates.state")
local util = require("crates.util")

local function attach()
    if state.cfg.src.cmp.enabled then
        require("crates.src.cmp").setup()
    end

    if state.cfg.lsp.enabled then
        require("crates.lsp").start_server()
    end

    core.update()
    state.cfg.on_attach(util.current_buf())
end

---@param cfg crates.UserConfig
local function setup(cfg)
    state.cfg = config.build(cfg)

    command.register()
    highlight.define()

    ---@type integer
    local group = vim.api.nvim_create_augroup("Crates", {})
    if state.cfg.autoload then
        if vim.fn.expand("%:t") == "Cargo.toml" then
            attach()
        end

        vim.api.nvim_create_autocmd("BufRead", {
            group = group,
            pattern = "Cargo.toml",
            callback = function(_)
                attach()
            end,
        })
    end

    -- initialize the throttled update function with timeout
    core.inner_throttled_update = async.throttle(core.update, state.cfg.autoupdate_throttle)

    if state.cfg.autoupdate then
        vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
            group = group,
            pattern = "Cargo.toml",
            callback = function()
                core.throttled_update(nil, false)
            end,
        })
    end

    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
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

---@class Crates
local M = {
    ---Setup config and auto commands.
    ---@type fun(cfg: crates.UserConfig)
    setup = setup,

    ---Disable UI elements (virtual text and diagnostics).
    ---@type fun()
    hide = core.hide,
    ---Enable UI elements (virtual text and diagnostics).
    ---@type fun()
    show = core.show,
    ---Enable or disable UI elements (virtual text and diagnostics).
    ---@type fun()
    toggle = core.toggle,
    ---Update data. Optionally specify which `p#buf` to update.
    ---@type fun(buf: integer|nil)
    update = core.update,
    ---Reload data (clears cache). Optionally specify which `p#buf` to reload.
    ---@type fun(buf: integer|nil)
    reload = core.reload,

    ---Upgrade the crate on the current line.
    ---If the `p#alt` flag is passed as true, the opposite of the `c#smart_insert` config
    ---option will be used to insert the version.
    ---@type fun(alt: boolean|nil)
    upgrade_crate = actions.upgrade_crate,
    ---Upgrade the crates on the lines visually selected.
    ---See `f#crates.upgrade_crate()`.
    ---@type fun(alt: boolean|nil)
    upgrade_crates = actions.upgrade_crates,
    ---Upgrade all crates in the buffer.
    ---See `f#crates.upgrade_crate()`.
    ---@type fun(alt: boolean|nil)
    upgrade_all_crates = actions.upgrade_all_crates,

    ---Update the crate on the current line.
    ---See `f#crates.upgrade_crate()`.
    ---@type fun(alt: boolean|nil)
    update_crate = actions.update_crate,
    ---Update the crates on the lines visually selected.
    ---See `f#crates.upgrade_crate()`.
    ---@type fun(alt: boolean|nil)
    update_crates = actions.update_crates,
    ---Update all crates in the buffer.
    ---See `f#crates.upgrade_crate()`.
    ---@type fun(alt: boolean|nil)
    update_all_crates = actions.update_all_crates,

    ---Expand a plain crate declaration into an inline table.
    ---@type fun()
    expand_plain_crate_to_inline_table = actions.expand_plain_crate_to_inline_table,
    ---Extract an crate declaration from a dependency section into a table.
    ---@type fun()
    extract_crate_into_table = actions.extract_crate_into_table,

    ---Open the homepage of the crate on the current line.
    ---@type fun()
    open_homepage = actions.open_homepage,
    ---Open the repository page of the crate on the current line.
    ---@type fun()
    open_repository = actions.open_repository,
    ---Open the documentation page of the crate on the current line.
    ---@type fun()
    open_documentation = actions.open_documentation,
    ---Open the `crates.io` page of the crate on the current line.
    ---@type fun()
    open_crates_io = actions.open_crates_io,
    ---Open the `lib.rs` page of the crate on the current line.
    ---@type fun()
    open_lib_rs = actions.open_lib_rs,

    ---Returns whether there is information to show in a popup.
    ---@type fun(): boolean
    popup_available = popup.available,
    ---Show/hide popup with crate details, all versions, all features or details about one feature.
    ---If `c#popup.autofocus` is disabled calling this again will focus the popup.
    ---@type fun()
    show_popup = popup.show,
    ---Same as `f#crates.show_popup()` but always show crate details.
    ---@type fun()
    show_crate_popup = popup.show_crate,
    ---Same as `f#crates.show_popup()` but always show versions.
    ---@type fun()
    show_versions_popup = popup.show_versions,
    ---Same as `f#crates.show_popup()` but always show features or features details.
    ---@type fun()
    show_features_popup = popup.show_features,
    ---Same as `f#crates.show_popup()` but always show dependencies.
    ---@type fun()
    show_dependencies_popup = popup.show_dependencies,
    ---Focus the popup (jump into the floating window).
    ---Optionally specify the line to jump to, inside the popup.
    ---@type fun(line: integer|nil)
    focus_popup = popup.focus,
    ---Hide the popup.
    ---@type fun()
    hide_popup = popup.hide,
}

return M
