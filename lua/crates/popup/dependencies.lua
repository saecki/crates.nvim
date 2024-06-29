local api = require("crates.api")
local async = require("crates.async")
local core = require("crates.core")
local popup = require("crates.popup.common")
local state = require("crates.state")
local types = require("crates.types")
local ApiDependencyKind = types.ApiDependencyKind
local util = require("crates.util")

local M = {}

---@class DepsContext
---@field buf integer
---@field history DepsHistoryEntry[]
---@field hist_idx integer

---@class DepsHistoryEntry
---@field crate_name string
---@field version ApiVersion
---@field line_mapping table<integer,ApiDependency>
---@field line integer -- 0-indexed


---@type fun(ctx: DepsContext, line: integer)
---@param ctx DepsContext
---@param line integer
local goto_dep = async.wrap(function(ctx, line)
    local hist_entry = ctx.history[ctx.hist_idx]

    local selected_dependency = hist_entry.line_mapping[line]
    if not selected_dependency then
        return
    end

    -- update current entry
    hist_entry.line = line

    local transaction = math.random()
    popup.transaction = transaction

    local crate_package = selected_dependency.package or selected_dependency.name
    ---@type ApiCrate|nil
    local crate = state.api_cache[crate_package]

    if not crate then
        popup.show_loading_indicator()

        if not api.is_fetching_crate(crate_package) then
            core.load_crate(crate_package)
        end

        local cancelled
        crate, cancelled = api.await_crate(crate_package)

        popup.hide_loading_indicator(transaction)
        if not crate or cancelled then
            return
        end
    end

    -- abort if the user has taken other actions
    if popup.transaction ~= transaction then
        return
    end

    local m, p, y = util.get_newest(crate.versions, selected_dependency.vers.reqs)
    local version = m or p or y
    assert(version, "crates cannot be published if no dependencies match the requirements")

    ctx.hist_idx = ctx.hist_idx + 1
    for i = ctx.hist_idx, #ctx.history, 1 do
        ctx.history[i] = nil
    end

    ---line_mapping is generated in `M.open_deps`
    ctx.history[ctx.hist_idx] = {
        crate_name = crate_package,
        version = version,
        line = 2,
    }

    M.open_deps(ctx, crate_package, version, {
        focus = true,
        update = true,
    })
end)

---@param ctx DepsContext
---@param line integer
local function jump_back_dep(ctx, line)
    if ctx.hist_idx == 1 then
        popup.hide()
        return
    end

    -- update current entry
    local current = ctx.history[ctx.hist_idx]
    current.line = line

    ctx.hist_idx = ctx.hist_idx - 1

    local entry = ctx.history[ctx.hist_idx]
    if not entry then
        return
    end

    M.open_deps(ctx, entry.crate_name, entry.version, {
        focus = true,
        line = entry.line,
        update = true,
    })
end

---@param ctx DepsContext
---@param line integer
local function jump_forward_dep(ctx, line)
    if ctx.hist_idx == #ctx.history then
        return
    end

    -- update current entry
    local current = ctx.history[ctx.hist_idx]
    current.line = line

    ctx.hist_idx = ctx.hist_idx + 1

    local entry = ctx.history[ctx.hist_idx]
    if not entry then
        return
    end

    M.open_deps(ctx, entry.crate_name, entry.version, {
        focus = true,
        line = entry.line,
        update = true,
    })
end

---@param ctx DepsContext
---@param crate_name string
---@param version ApiVersion
---@param opts WinOpts
function M.open_deps(ctx, crate_name, version, opts)
    popup.type = popup.Type.DEPENDENCIES

    popup.omit_loading_transaction()

    local deps = version.deps

    local title = string.format(state.cfg.popup.text.title, crate_name .. " " .. version.num)
    local deps_width = 0
    ---@type HighlightText[][]
    local deps_text_index = {}

    ---@class HlTextDepList: HighlightText[]
    ---@field dep ApiDependency

    ---@type HlTextDepList[]
    local normal_deps_text = {}
    ---@type HlTextDepList[]
    local build_deps_text = {}
    ---@type HlTextDepList[]
    local dev_deps_text = {}

    for _, d in ipairs(deps) do
        ---@type string, string
        local text, hl
        local name = d.name
        if d.package then
            name = string.format("%s (%s)", d.name, d.package)
        end
        if d.opt then
            text = string.format(state.cfg.popup.text.optional, name)
            hl = state.cfg.popup.highlight.optional
        else
            text = string.format(state.cfg.popup.text.dependency, name)
            hl = state.cfg.popup.highlight.dependency
        end
        ---@type HighlightText
        local t = { text = text, hl = hl }

        ---@type HlTextDepList
        local line = { t, dep = d }
        if d.kind == ApiDependencyKind.NORMAL then
            table.insert(normal_deps_text, line)
        elseif d.kind == ApiDependencyKind.BUILD then
            table.insert(build_deps_text, line)
        elseif d.kind == ApiDependencyKind.DEV then
            table.insert(dev_deps_text, line)
        end
        table.insert(deps_text_index, line)
        deps_width = math.max(vim.fn.strdisplaywidth(t.text), deps_width)
    end

    local vers_width = 0
    if state.cfg.popup.show_dependency_version then
        for i, line in ipairs(deps_text_index) do
            local dep_text = line[1]
            ---@type integer
            local diff = deps_width - vim.fn.strdisplaywidth(dep_text.text)
            local vers = deps[i].vers.text
            dep_text.text = dep_text.text .. string.rep(" ", diff)

            ---@type HighlightText
            local vers_text = {
                text = string.format(state.cfg.popup.text.dependency_version, vers),
                hl = state.cfg.popup.highlight.dependency_version,
            }
            table.insert(line, vers_text)

            ---@type integer
            vers_width = math.max(vim.fn.strdisplaywidth(vers_text.text), vers_width)
        end
    end

    ---@type HighlightText[][]
    local deps_text = {}
    ---@type table<integer,ApiDependency>
    local line_mapping = {}
    local line_idx = popup.TOP_OFFSET
    if #normal_deps_text > 0 then
        table.insert(deps_text, { {
            text = state.cfg.popup.text.normal_dependencies_title,
            hl = state.cfg.popup.highlight.normal_dependencies_title,
        } })
        line_idx = line_idx + 1

        for _, t in ipairs(normal_deps_text) do
            table.insert(deps_text, t)
            line_mapping[line_idx] = t.dep
            ---@type integer
            line_idx = line_idx + 1
        end
    end
    if #build_deps_text > 0 then
        if #deps_text > 0 then
            table.insert(deps_text, {})
            line_idx = line_idx + 1
        end
        table.insert(deps_text, { {
            text = state.cfg.popup.text.build_dependencies_title,
            hl = state.cfg.popup.highlight.build_dependencies_title,
        } })
        line_idx = line_idx + 1

        for _, t in ipairs(build_deps_text) do
            table.insert(deps_text, t)
            line_mapping[line_idx] = t.dep
            line_idx = line_idx + 1
        end
    end
    if #dev_deps_text > 0 then
        if #deps_text > 0 then
            table.insert(deps_text, {})
            line_idx = line_idx + 1
        end
        table.insert(deps_text, { {
            text = state.cfg.popup.text.dev_dependencies_title,
            hl = state.cfg.popup.highlight.dev_dependencies_title,
        } })
        line_idx = line_idx + 1

        for _, t in ipairs(dev_deps_text) do
            table.insert(deps_text, t)
            line_mapping[line_idx] = t.dep
            line_idx = line_idx + 1
        end
    end

    ctx.history[ctx.hist_idx].line_mapping = line_mapping

    local width = popup.win_width(title, deps_width + vers_width)
    local height = popup.win_height(deps_text)

    if opts.update then
        popup.update_win(width, height, title, deps_text, opts)
    else
        ---@param _win integer
        ---@param buf integer
        popup.open_win(width, height, title, deps_text, opts, function(_win, buf)
            for _, k in ipairs(state.cfg.popup.keys.goto_item) do
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

            for _, k in ipairs(state.cfg.popup.keys.jump_forward) do
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

            for _, k in ipairs(state.cfg.popup.keys.jump_back) do
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

---@param crate_name string
---@param version ApiVersion
---@param opts WinOpts
function M.open(crate_name, version, opts)
    local ctx = {
        buf = util.current_buf(),
        history = {
            {
                crate_name = crate_name,
                version = version,
                line = opts.line or 2,
            },
        },
        hist_idx = 1,
    }
    M.open_deps(ctx, crate_name, version, opts)
end

return M
