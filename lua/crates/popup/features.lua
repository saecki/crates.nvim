local edit = require("crates.edit")
local popup = require("crates.popup.common")
local state = require("crates.state")
local toml = require("crates.toml")
local TomlCrateSyntax = toml.TomlCrateSyntax
local util = require("crates.util")
local FeatureInfo = util.FeatureInfo

local M = {}

---@class FeatureContext
---@field buf integer
---@field crate TomlCrate
---@field version ApiVersion
---@field history FeatHistoryEntry[]
---@field hist_idx integer

---@class FeatHistoryEntry
---@field feature ApiFeature
---@field line integer -- 0-indexed

---@param features_info table<string,FeatureInfo>
---@param feature string
---@return HighlightText[]
local function feature_text(features_info, feature)
    ---@type string, string
    local text, hl
    local info = features_info[feature]
    if info == FeatureInfo.ENABLED then
        text = string.format(state.cfg.popup.text.enabled, feature)
        hl = state.cfg.popup.highlight.enabled
    elseif info == FeatureInfo.TRANSITIVE then
        text = string.format(state.cfg.popup.text.transitive, feature)
        hl = state.cfg.popup.highlight.transitive
    else
        text = string.format(state.cfg.popup.text.feature, feature)
        hl = state.cfg.popup.highlight.feature
    end
    return { { text = text, hl = hl } }
end

---@param ctx FeatureContext
---@param line integer
local function toggle_feature(ctx, line)
    local index = popup.item_index(line)
    local features = ctx.version.features
    local entry = ctx.history[ctx.hist_idx]

    ---@type ApiFeature?
    local selected_feature
    if entry.feature then
        local m = entry.feature.members[index]
        if m then
            selected_feature = features:get_feat(m)
        end
    else
        selected_feature = features.list[index]
    end
    if not selected_feature then
        return
    end

    local feat_name = selected_feature.name
    if selected_feature.dep then
        local parent_name = string.sub(feat_name, 5)
        local parent_feat = features.map[parent_name]

        if not parent_feat then
            -- no direct explicit parent feature, so just toggle the implicit feature
        elseif vim.tbl_contains(parent_feat.members, feat_name) then
            if #parent_feat.members > 1 then
                util.notify(vim.log.levels.INFO, "Cannot enable/disable '%s' directly; instead toggle its parent feature '%s'", feat_name, parent_name)
                return
            else
                -- the explicit parent feature only contains the dependency feature, so toggle it instead
            end
        else
            -- the parent feature named like the dependency, doesn't include the `dep:` feature,
            -- so find other features, that include it.
            local parents = {}
            for _, f in ipairs(features.list) do
                if vim.tbl_contains(f.members, feat_name) then
                    table.insert(parents, string.format("'%s'", f.name))
                end
            end

            local parent_names = table.concat(parents, ", ")
            util.notify(vim.log.levels.INFO, "Cannot enable/disable '%s' directly; instead toggle a parent feature: %s", feat_name, parent_names)
            return
        end

        feat_name = parent_name
    end

    ---@type Span
    local line_span
    local crate_feature = ctx.crate:get_feat(feat_name)
    if selected_feature.name == "default" then
        if crate_feature ~= nil or ctx.crate:is_def_enabled() then
            line_span = edit.disable_def_features(ctx.buf, ctx.crate, crate_feature)
        else
            line_span = edit.enable_def_features(ctx.buf, ctx.crate)
        end
    else
        if crate_feature then
            line_span = edit.disable_feature(ctx.buf, ctx.crate, crate_feature)
        else
            line_span = edit.enable_feature(ctx.buf, ctx.crate, feat_name)
        end
    end

    -- update crate version, features, and default_features positions
    -- because they probably have changed after the edits, so toggling
    -- multiple features will be correct
    if ctx.crate.syntax == TomlCrateSyntax.TABLE then
        for line_nr in line_span:iter() do
            ---@type string
            local text = vim.api.nvim_buf_get_lines(ctx.buf, line_nr, line_nr + 1, false)[1]
            text = toml.trim_comments(text)

            local def = toml.parse_crate_table_bool(text, line_nr, toml.TABLE_DEF_PATTERN)
            if def then
                ctx.crate.def = def
            end
            local feat = toml.parse_crate_table_str_array(text, line_nr, toml.TABLE_FEAT_PATTERN)
            if feat then
                ctx.crate.feat = feat
            end

            ctx.crate = toml.Crate.new(ctx.crate)
        end
    else -- ctx.crate.syntax == TomlCrateSyntax.INLINE_TABLE or ctx.crate.syntax == TomlCrateSyntax.PLAIN then
        local line_nr = line_span.s
        ---@type string
        local text = vim.api.nvim_buf_get_lines(ctx.buf, line_nr, line_nr + 1, false)[1]
        text = toml.trim_comments(text)

        local raw_crate = toml.parse_inline_crate(text, line_nr)
        assert(raw_crate, "edits were valid")
        local crate = toml.Crate.new(raw_crate)
        ctx.crate.syntax = crate.syntax
        ctx.crate.vers = crate.vers
        ctx.crate.feat = crate.feat
        ctx.crate.def = crate.def
    end

    -- update buffer
    local features_text = {}
    local features_info = util.features_info(ctx.crate, features)
    if entry.feature then
        for _, m in ipairs(entry.feature.members) do
            local hl_text = feature_text(features_info, m)
            table.insert(features_text, hl_text)
        end
    else
        for _, f in ipairs(features.list) do
            local hl_text = feature_text(features_info, f.name)
            table.insert(features_text, hl_text)
        end
    end

    popup.update_buf_body(features_text)
end

---@param ctx FeatureContext
---@param line integer
local function goto_feature(ctx, line)
    local index = popup.item_index(line)
    local crate = ctx.crate
    local version = ctx.version
    local feature = ctx.history[ctx.hist_idx].feature

    ---@type ApiFeature?
    local selected_feature
    if feature then
        local m = feature.members[index]
        if m then
            selected_feature = version.features.map[m]
        end
    else
        selected_feature = version.features.list[index]
    end
    if not selected_feature then
        return
    end

    M.open_feature_details(ctx, crate, version, selected_feature, {
        focus = true,
        update = true,
    })

    -- update current entry
    local current = ctx.history[ctx.hist_idx]
    current.line = line

    ctx.hist_idx = ctx.hist_idx + 1
    for i = ctx.hist_idx, #ctx.history, 1 do
        ctx.history[i] = nil
    end

    ctx.history[ctx.hist_idx] = {
        feature = selected_feature,
        line = 2,
    }
end

---@param ctx FeatureContext
---@param line integer
local function jump_back_feature(ctx, line)
    local crate = ctx.crate
    local version = ctx.version

    if ctx.hist_idx == 1 then
        popup.hide()
        return
    end

    -- update current entry
    local current = ctx.history[ctx.hist_idx]
    current.line = line

    ctx.hist_idx = ctx.hist_idx - 1

    if ctx.hist_idx == 1 then
        M.open_features(ctx, crate, version, {
            focus = true,
            line = ctx.history[1].line,
            update = true,
        })
    else
        local entry = ctx.history[ctx.hist_idx]
        if not entry then
            return
        end

        M.open_feature_details(ctx, crate, version, entry.feature, {
            focus = true,
            line = entry.line,
            update = true,
        })
    end
end

---@param ctx FeatureContext
---@param line integer
local function jump_forward_feature(ctx, line)
    local crate = ctx.crate
    local version = ctx.version

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

    M.open_feature_details(ctx, crate, version, entry.feature, {
        focus = true,
        line = entry.line,
        update = true,
    })
end

---@param ctx FeatureContext
---@return fun(win: integer, buf: integer)
local function config_feat_win(ctx)
    ---@param _win integer
    ---@param buf integer
    return function(_win, buf)
        for _, k in ipairs(state.cfg.popup.keys.toggle_feature) do
            vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
                callback = function()
                    local line = util.cursor_pos()
                    toggle_feature(ctx, line)
                end,
                noremap = true,
                silent = true,
                desc = "Toggle feature",
            })
        end

        for _, k in ipairs(state.cfg.popup.keys.goto_item) do
            vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
                callback = function()
                    local line = util.cursor_pos()
                    goto_feature(ctx, line)
                end,
                noremap = true,
                silent = true,
                desc = "Goto feature",
            })
        end

        for _, k in ipairs(state.cfg.popup.keys.jump_forward) do
            vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
                callback = function()
                    local line = util.cursor_pos()
                    jump_forward_feature(ctx, line)
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
                    jump_back_feature(ctx, line)
                end,
                noremap = true,
                silent = true,
                desc = "Jump back",
            })
        end
    end
end

---@param ctx FeatureContext
---@param crate TomlCrate
---@param version ApiVersion
---@param opts WinOpts
function M.open_features(ctx, crate, version, opts)
    popup.type = popup.Type.FEATURES

    local features = version.features
    local title = string.format(state.cfg.popup.text.title, crate:package() .. " " .. version.num)
    local feat_width = 0
    ---@type HighlightText[][]
    local features_text = {}

    local features_info = util.features_info(crate, features)
    for _, f in ipairs(features.list) do
        local hl_text = feature_text(features_info, f.name)
        table.insert(features_text, hl_text)
        local w = 0
        for _, t in ipairs(hl_text) do
            ---@type integer
            w = w + vim.fn.strdisplaywidth(t.text)
        end
        feat_width = math.max(w, feat_width)
    end

    local width = popup.win_width(title, feat_width)
    local height = popup.win_height(features.list)

    if opts.update then
        popup.update_win(width, height, title, features_text, opts)
    else
        popup.open_win(width, height, title, features_text, opts, config_feat_win(ctx))
    end
end

---@param ctx FeatureContext
---@param crate TomlCrate
---@param version ApiVersion
---@param feature ApiFeature
---@param opts WinOpts
function M.open_feature_details(ctx, crate, version, feature, opts)
    popup.type = popup.Type.FEATURES

    local features = version.features
    local members = feature.members
    local title = string.format(state.cfg.popup.text.title, crate:package() .. " " .. version.num .. " " .. feature.name)
    local feat_width = 0
    local features_text = {}

    local features_info = util.features_info(crate, features)
    for _, m in ipairs(members) do
        local hl_text = feature_text(features_info, m)
        table.insert(features_text, hl_text)
        local w = 0
        for _, t in ipairs(hl_text) do
            ---@type integer
            w = w + vim.fn.strdisplaywidth(t.text)
        end
        feat_width = math.max(w, feat_width)
    end

    local width = popup.win_width(title, feat_width)
    local height = popup.win_height(members)

    if opts.update then
        popup.update_win(width, height, title, features_text, opts)
    else
        popup.open_win(width, height, title, features_text, opts, config_feat_win(ctx))
    end
end

---@param crate TomlCrate
---@param version ApiVersion
---@param opts WinOpts
function M.open(crate, version, opts)
    local ctx = {
        buf = util.current_buf(),
        crate = crate,
        version = version,
        history = {
            { feature = nil, line = opts.line or 2 },
        },
        hist_idx = 1,
    }
    M.open_features(ctx, crate, version, opts)
end

---@param crate TomlCrate
---@param version ApiVersion
---@param feature ApiFeature
---@param opts WinOpts
function M.open_details(crate, version, feature, opts)
    local ctx = {
        buf = util.current_buf(),
        crate = crate,
        version = version,
        history = {
            { feature = nil,     line = 2 },
            { feature = feature, line = opts.line or 2 },
        },
        hist_idx = 2,
    }
    M.open_feature_details(ctx, crate, version, feature, opts)
end

return M
