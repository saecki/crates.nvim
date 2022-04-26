local record M
    open_deps: function(DepsContext, string, Version, WinOpts)

    record DepsContext
        buf: integer
        history: {DepsHistoryEntry}
        hist_idx: integer
    end

    record DepsHistoryEntry
        crate_name: string
        version: Version
        line: integer -- 0-indexed
    end
end

local DepsContext = M.DepsContext
local api = require("crates.api")
local async = require("crates.async")
local core = require("crates.core")
local popup = require("crates.popup.common")
local HighlightText = popup.HighlightText
local WinOpts = popup.WinOpts
local state = require("crates.state")
local types = require("crates.types")
local Dependency = types.Dependency
local Version = types.Version
local util = require("crates.util")

local goto_dep = async.wrap(function(ctx: DepsContext, line: integer)
    local index = popup.item_index(line)
    local hist_entry = ctx.history[ctx.hist_idx]
    local deps = hist_entry.version.deps as {Dependency}

    if not deps or not deps[index] then return end
    local selected_dependency = deps[index]

    -- update current entry
    hist_entry.line = line

    local transaction = math.random()
    popup.transaction = transaction

    local crate_name = selected_dependency.name
    local versions = state.vers_cache[crate_name]

    if not versions then
        popup.show_loading_indicator()

        if not api.is_fetching_vers(crate_name) then
            core.reload_crate(crate_name)
        end

        local cancelled: boolean
        versions, cancelled = api.await_vers(crate_name)

        popup.hide_loading_indicator(transaction)
        if cancelled then return end
    end

    -- abort if the user has taken other actions
    if popup.transaction ~= transaction then
        return
    end

    local m, p, y = util.get_newest(versions, false, selected_dependency.vers.reqs)
    local version = m or p or y

    if not version.deps then
        popup.show_loading_indicator()

        if not api.is_fetching_deps(crate_name, version.num) then
            core.reload_deps(crate_name, versions, version)
        end
        local _, cancelled = api.await_deps(crate_name, version.num)

        popup.hide_loading_indicator(transaction)
        if cancelled then return end
    end

    -- abort if the user has taken other actions
    if popup.transaction ~= transaction then
        return
    end

    ctx.hist_idx = ctx.hist_idx + 1
    for i=ctx.hist_idx, #ctx.history, 1 do
        ctx.history[i] = nil
    end

    ctx.history[ctx.hist_idx] = {
        crate_name = crate_name,
        version = version,
        line = 2,
    }

    M.open_deps(ctx, crate_name, version, {
        focus = true,
        update = true,
    })
end)

local function jump_back_dep(ctx: DepsContext, line: integer)
    if ctx.hist_idx == 1 then
        popup.hide()
        return
    end

    -- update current entry
    local current = ctx.history[ctx.hist_idx]
    current.line = line

    ctx.hist_idx = ctx.hist_idx - 1

    local entry = ctx.history[ctx.hist_idx]
    if not entry then return end

    M.open_deps(ctx, entry.crate_name, entry.version, {
        focus = true,
        line = entry.line,
        update = true,
    })
end

local function jump_forward_dep(ctx: DepsContext, line: integer)
    if ctx.hist_idx == #ctx.history then
        return
    end

    -- update current entry
    local current = ctx.history[ctx.hist_idx]
    current.line = line

    ctx.hist_idx = ctx.hist_idx + 1

    local entry = ctx.history[ctx.hist_idx]
    if not entry then return end

    M.open_deps(ctx, entry.crate_name, entry.version, {
        focus = true,
        line = entry.line,
        update = true,
    })
end

function M.open_deps(ctx: DepsContext, crate_name: string, version: Version, opts: WinOpts)
    popup.type = "dependencies"

    popup.omit_loading_transaction()

    local deps = version.deps as {Dependency}
    if not deps then return end

    local title = string.format(state.cfg.popup.text.title, crate_name.." "..version.num)
    local deps_width = 0
    local deps_text: {HighlightText} = {}

    for _,d in ipairs(deps) do
        local text, hl: string, string
        if d.opt then
            text = string.format(state.cfg.popup.text.optional, d.name)
            hl = state.cfg.popup.highlight.optional
        else
            text = string.format(state.cfg.popup.text.dependency, d.name)
            hl = state.cfg.popup.highlight.dependency
        end

        table.insert(deps_text, { text = text, hl = hl })
        deps_width = math.max(vim.fn.strdisplaywidth(text) as integer, deps_width)
    end

    local vers_width = 0
    if state.cfg.popup.show_dependency_version then
        for i,d in ipairs(deps_text) do
            local diff = deps_width - vim.fn.strdisplaywidth(d.text) as integer
            local date = deps[i].vers.text
            d.text = d.text..string.rep(" ", diff)
            d.suffix = string.format(state.cfg.popup.text.dependency_version, date)
            d.suffix_hl = state.cfg.popup.highlight.dependency_version

            vers_width = math.max(vim.fn.strdisplaywidth(d.suffix) as integer, vers_width)
        end
    end

    local width = popup.win_width(title, deps_width + vers_width)
    local height = popup.win_height(deps)

    if opts.update then
        popup.update_win(width, height, title, deps_text, opts)
    else
        popup.open_win(width, height, title, deps_text, opts, function(_win: integer, buf: integer)
            for _,k in ipairs(state.cfg.popup.keys.goto_item) do
                vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
                    callback = function()
                        local line = util.cursor_pos()
                        goto_dep(ctx, line)
                    end,
                    noremap = true,
                    silent = true,
                    desc = "Goto dependency",
                })
            end

            for _,k in ipairs(state.cfg.popup.keys.jump_forward) do
                vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
                    callback = function()
                        local line = util.cursor_pos()
                        jump_forward_dep(ctx, line)
                    end,
                    noremap = true,
                    silent = true,
                    desc = "Jump forward",
                })
            end

            for _,k in ipairs(state.cfg.popup.keys.jump_back) do
                vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
                    callback = function()
                        local line = util.cursor_pos()
                        jump_back_dep(ctx, line)
                    end,
                    noremap = true,
                    silent = true,
                    desc = "Jump back",
                })
            end
        end)
    end
end

function M.open(crate_name: string, version: Version, opts: WinOpts)
    local ctx = {
        buf = util.current_buf(),
        history = {
            { crate_name = crate_name, version = version, line = opts and opts.line or 2 },
        },
        hist_idx = 1,
    }
    M.open_deps(ctx, crate_name, version, opts)
end

return M
