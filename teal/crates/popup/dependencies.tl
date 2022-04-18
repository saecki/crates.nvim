local record M
    deps_ctx: DepsContext|nil

    open_deps: function(string, Version, WinOpts)

    record DepsContext
        buf: integer
        transaction: number|nil
        history: {DepsHistoryEntry}
        history_index: integer
    end

    record DepsHistoryEntry
        crate_name: string
        version: Version
        line: integer -- 1 indexed
    end
end

local DepsContext = M.DepsContext

local core = require("crates.core")
local state = require("crates.state")
local api = require("crates.api")
local Version = api.Version
local Dependency = api.Dependency
local util = require("crates.util")
local popup = require("crates.popup.common")
local WinOpts = popup.WinOpts
local HighlightText = popup.HighlightText

local function _goto_dep(crate_name: string, version: Version)
    if not M.deps_ctx then return end
    local deps_ctx = M.deps_ctx as DepsContext

    local hist_index = deps_ctx.history_index

    M.open_deps(crate_name, version, {
        focus = true,
        update = true,
    })

    deps_ctx.history_index = hist_index + 1
    hist_index = deps_ctx.history_index
    for i=hist_index, #deps_ctx.history, 1 do
        deps_ctx.history[i] = nil
    end

    -- omit loading transaction if any
    deps_ctx.transaction = nil

    deps_ctx.history[hist_index] = {
        crate_name = crate_name,
        version = version,
        line = 3,
    }
end

local function show_loading_indicator()
    vim.api.nvim_buf_set_extmark(popup.buf, popup.NAMESPACE, 0, -1, {
        virt_text = { { core.cfg.popup.text.loading, core.cfg.popup.highlight.loading } },
        virt_text_pos = "right_align",
        hl_mode = "combine",
    })
end

local function hide_loading_indicator()
    if popup.buf then
        vim.api.nvim_buf_clear_namespace(popup.buf, popup.NAMESPACE, 0, 1)
    end
end

local function fetch_deps(
    crate_name: string,
    versions: {Version},
    version: Version,
    deps_ctx: DepsContext,
    transaction: number
)
    if not api.is_fetching_deps(crate_name, version.num) then
        state.reload_deps(crate_name, versions, version)
    end
    api.add_deps_callback(crate_name, version.num, function(_deps: {Dependency}, cancelled: boolean)
        hide_loading_indicator()
        if cancelled then return end

        -- only goto dependency if the user hasn't taken other actions
        if M.deps_ctx == deps_ctx and deps_ctx.transaction == transaction then
            _goto_dep(crate_name, version)
        end
    end)
end

local function goto_dep(index: integer)
    local deps_ctx = M.deps_ctx as DepsContext
    if not deps_ctx then return end

    local hist_index = deps_ctx.history_index
    local hist_entry = deps_ctx.history[hist_index]
    local deps = hist_entry.version.deps as {Dependency}

    if not deps or not deps[index] then return end
    local selected_dependency = deps[index]

    -- update current entry
    local current = deps_ctx.history[hist_index]
    current.line = index + popup.TOP_OFFSET

    local crate_name = selected_dependency.name
    local versions = core.vers_cache[crate_name]
    if versions then
        local m, p, y = util.get_newest(versions, false, selected_dependency.vers.reqs)
        local match = m or p or y

        if match.deps then
            _goto_dep(crate_name, match)
        else
            local transaction = math.random()
            deps_ctx.transaction = transaction
            show_loading_indicator()
            fetch_deps(crate_name, versions, match, deps_ctx, transaction)
        end
    else
        local transaction = math.random()
        deps_ctx.transaction = transaction

        show_loading_indicator()

        if not api.is_fetching_vers(crate_name) then
            state.reload_crate(crate_name)
        end

        api.add_vers_callback(crate_name, function(versions: {Version}, cancelled: boolean)
            if cancelled then
                hide_loading_indicator()
                return
            end

            local m, p, y = util.get_newest(versions, false, selected_dependency.vers.reqs)
            local match = m or p or y

            fetch_deps(crate_name, versions, match, deps_ctx, transaction)
        end)
    end
end

local function jump_back_dep(line: integer)
    local deps_ctx = M.deps_ctx as DepsContext
    if not deps_ctx then return end

    local hist_index = deps_ctx.history_index

    if hist_index == 1 then
        popup.hide()
        return
    end

    -- update current entry
    local current = deps_ctx.history[hist_index]
    current.line = line

    deps_ctx.history_index = hist_index - 1
    hist_index = deps_ctx.history_index

    local entry = deps_ctx.history[hist_index]
    if not entry then return end

    -- omit loading transaction if any
    deps_ctx.transaction = nil

    M.open_deps(entry.crate_name, entry.version, {
        focus = true,
        line = entry.line,
        update = true,
    })
end

local function jump_forward_dep(line: integer)
    local deps_ctx = M.deps_ctx as DepsContext
    if not deps_ctx then return end

    local hist_index = deps_ctx.history_index

    if hist_index == #deps_ctx.history then
        return
    end

    -- update current entry
    local current = deps_ctx.history[hist_index]
    current.line = line

    deps_ctx.history_index = hist_index + 1
    hist_index = deps_ctx.history_index

    local entry = deps_ctx.history[hist_index]
    if not entry then return end

    -- omit loading transaction if any
    deps_ctx.transaction = nil

    M.open_deps(entry.crate_name, entry.version, {
        focus = true,
        line = entry.line,
        update = true,
    })
end

function M.open(crate_name: string, version: Version, opts: WinOpts)
    M.deps_ctx = {
        buf = util.current_buf(),
        history = {
            { crate_name = crate_name, version = version, line = opts and opts.line or 3 },
        },
        history_index = 1,
    }
    M.open_deps(crate_name, version, opts)
end

function M.open_deps(crate_name: string, version: Version, opts: WinOpts)
    popup.type = "dependencies"

    local deps = version.deps as {Dependency}
    if not deps then return end

    local title = string.format(core.cfg.popup.text.title, crate_name.." "..version.num)
    local deps_width = 0
    local deps_text: {HighlightText} = {}

    for _,d in ipairs(deps) do
        local text, hl: string, string
        if d.opt then
            text = string.format(core.cfg.popup.text.optional, d.name)
            hl = core.cfg.popup.highlight.optional
        else
            text = string.format(core.cfg.popup.text.dependency, d.name)
            hl = core.cfg.popup.highlight.dependency
        end

        table.insert(deps_text, { text = text, hl = hl })
        deps_width = math.max(vim.fn.strdisplaywidth(text) as integer, deps_width)
    end

    local vers_width = 0
    if core.cfg.popup.show_dependency_version then
        for i,d in ipairs(deps_text) do
            local diff = deps_width - vim.fn.strdisplaywidth(d.text) as integer
            local date = deps[i].vers.text
            d.text = d.text..string.rep(" ", diff)
            d.suffix = string.format(core.cfg.popup.text.dependency_version, date)
            d.suffix_hl = core.cfg.popup.highlight.dependency_version

            vers_width = math.max(vim.fn.strdisplaywidth(d.suffix) as integer, vers_width)
        end
    end

    local width = popup.win_width(title, deps_width + vers_width)
    local height = popup.win_height(deps)

    if opts.update then
        popup.update_win(width, height, title, deps_text, opts)
    else
        popup.open_win(width, height, title, deps_text, opts, function()
            for _,k in ipairs(core.cfg.popup.keys.goto_item) do
                vim.api.nvim_buf_set_keymap(popup.buf, "n", k, "", {
                    callback = function()
                        goto_dep(vim.api.nvim_win_get_cursor(0)[1] - popup.TOP_OFFSET)
                    end,
                    noremap = true,
                    silent = true,
                    desc = "Goto dependency",
                })
            end

            for _,k in ipairs(core.cfg.popup.keys.jump_forward) do
                vim.api.nvim_buf_set_keymap(popup.buf, "n", k, "", {
                    callback = function()
                        jump_forward_dep(vim.api.nvim_win_get_cursor(0)[1])
                    end,
                    noremap = true,
                    silent = true,
                    desc = "Jump forward",
                })
            end

            for _,k in ipairs(core.cfg.popup.keys.jump_back) do
                vim.api.nvim_buf_set_keymap(popup.buf, "n", k, "", {
                    callback = function()
                        jump_back_dep(vim.api.nvim_win_get_cursor(0)[1])
                    end,
                    noremap = true,
                    silent = true,
                    desc = "Jump back",
                })
            end
        end)
    end
end

return M
