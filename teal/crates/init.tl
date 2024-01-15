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

    -- Expand a plain crate declaration into an inline table.
    expand_plain_crate_to_inline_table: function()
    -- Extract an crate declaration from a dependency section into a table.
    extract_crate_into_table: function()

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
local async = require("crates.async")
local command = require("crates.command")
local config = require("crates.config")
local Config = config.Config
local core = require("crates.core")
local highlight = require("crates.highlight")
local popup = require("crates.popup")
local state = require("crates.state")

local record AutocmdInfo
  buf: integer
end


function M.attach()
    if state.cfg.src.cmp.enabled then
        require("crates.src.cmp").setup()
    end

    if state.cfg.lsp.enabled then
        require("crates.lsp").start_server()
    end

    core.update()
    state.cfg.on_attach(vim.api.nvim_get_current_buf())
end

function M.setup(cfg: Config)
    state.cfg = config.build(cfg)

    command.register()
    highlight.define()

    local group = vim.api.nvim_create_augroup("Crates", {})
    if state.cfg.autoload then
        if vim.fn.expand("%:t") == "Cargo.toml" then
            M.attach()
        end

        vim.api.nvim_create_autocmd("BufRead", {
            group = group,
            pattern = "Cargo.toml",
            callback = function(_: AutocmdInfo)
                M.attach()
            end,
        })
    end

    -- initialize the throttled update function with timeout
    core.inner_throttled_update = async.throttle(M.update, state.cfg.autoupdate_throttle) as function()

    if state.cfg.autoupdate then
        vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
            group = group,
            pattern = "Cargo.toml",
            callback = function()
                core.throttled_update(nil, false)
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

M.hide = core.hide
M.show = core.show
M.toggle = core.toggle
M.update = core.update
M.reload = core.reload

M.upgrade_crate = actions.upgrade_crate
M.upgrade_crates = actions.upgrade_crates
M.upgrade_all_crates = actions.upgrade_all_crates
M.update_crate = actions.update_crate
M.update_crates = actions.update_crates
M.update_all_crates = actions.update_all_crates

M.expand_plain_crate_to_inline_table = actions.expand_plain_crate_to_inline_table
M.extract_crate_into_table = actions.extract_crate_into_table

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
