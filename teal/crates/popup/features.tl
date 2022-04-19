local record M
    open_features: function(FeatureContext, Crate, Version, WinOpts)
    open_feature_details: function(FeatureContext, Crate, Version, Feature, WinOpts)
    
    record FeatureContext
        buf: integer
        crate: Crate
        version: Version
        history: {FeatHistoryEntry}
        history_index: integer
    end

    record FeatHistoryEntry
        feature: Feature
        line: integer -- 1 indexed
    end
end

local FeatureContext = M.FeatureContext
local FeatHistoryEntry = M.FeatHistoryEntry

local core = require("crates.core")
local api = require("crates.api")
local Version = api.Version
local Feature = api.Feature
local toml = require("crates.toml")
local Crate = toml.Crate
local util = require("crates.util")
local FeatureInfo = util.FeatureInfo
local Range = require("crates.types").Range
local popup = require("crates.popup.common")
local HighlightText = popup.HighlightText
local WinOpts = popup.WinOpts

local function feature_text(features_info: {string:FeatureInfo}, feature: Feature): HighlightText
    local text, hl: string, string
    local info = features_info[feature.name]
    if info.enabled then
        text = string.format(core.cfg.popup.text.enabled, feature.name)
        hl = core.cfg.popup.highlight.enabled
    elseif info.transitive then
        text = string.format(core.cfg.popup.text.transitive, feature.name)
        hl = core.cfg.popup.highlight.transitive
    else
        text = string.format(core.cfg.popup.text.feature, feature.name)
        hl = core.cfg.popup.highlight.feature
    end
    return { text = text, hl = hl }
end

local function toggle_feature(ctx: FeatureContext, line: integer)
    local index = line - popup.TOP_OFFSET
    local features = ctx.version.features
    local hist_index = ctx.history_index
    local entry = ctx.history[hist_index]

    local selected_feature: Feature
    if entry.feature then
        local m = entry.feature.members[index]
        if m then
            selected_feature = features:get_feat(m)
        end
    else
        selected_feature = features[index]
    end
    if not selected_feature then return end

    local line_range: Range
    local crate_feature = ctx.crate:get_feat(selected_feature.name)
    if selected_feature.name == "default" then
        if crate_feature ~= nil or ctx.crate:is_def_enabled() then
            line_range = util.disable_def_features(ctx.buf, ctx.crate, crate_feature)
        else
            line_range = util.enable_def_features(ctx.buf, ctx.crate)
        end
    else
        if crate_feature then
            line_range = util.disable_feature(ctx.buf, ctx.crate, crate_feature)
        else
            line_range = util.enable_feature(ctx.buf, ctx.crate, selected_feature)
        end
    end

    -- update crate position
    local c = {}
    for l in line_range:iter() do
        local line = vim.api.nvim_buf_get_lines(ctx.buf, l, l + 1, false)[1]
        line = toml.trim_comments(line)
        if ctx.crate.syntax == "table" then
            local cr = toml.parse_crate_table_vers(line)
            if cr then
                cr.vers.line = l
                table.insert(c, cr)
            end
            local cd = toml.parse_crate_table_def(line)
            if cd then
                cd.def.line = l
                table.insert(c, cd)
            end
            local cf = toml.parse_crate_table_feat(line)
            if cf then
                cf.feat.line = l
                table.insert(c, cf)
            end
        elseif ctx.crate.syntax == "plain" or ctx.crate.syntax == "inline_table" then
            local cf = toml.parse_crate(line)
            if cf and cf.vers then
                cf.vers.line = l
            end
            if cf and cf.def then
                cf.def.line = l
            end
            if cf and cf.feat then
                cf.feat.line = l
            end
            table.insert(c, cf)
        end
    end
    ctx.crate = Crate.new(vim.tbl_extend("force", ctx.crate as table, unpack(c) as table) as Crate)

    -- update buffer
    local features_text = {}
    local features_info = util.features_info(ctx.crate, features)
    if entry.feature then
        for _,m in ipairs(entry.feature.members) do
            local f = features:get_feat(m) or {
                name = m,
                members = {},
            }

            local hi_text = feature_text(features_info, f)
            table.insert(features_text, hi_text)
        end
    else
        for _,f in ipairs(features) do
            local hi_text = feature_text(features_info, f)
            table.insert(features_text, hi_text)
        end
    end

    vim.api.nvim_buf_set_option(popup.buf, "modifiable", true)
    for i,v in ipairs(features_text) do
        vim.api.nvim_buf_set_lines(popup.buf, popup.TOP_OFFSET + i - 1, popup.TOP_OFFSET + i, false, { v.text })
        vim.api.nvim_buf_add_highlight(popup.buf, popup.NAMESPACE, v.hl, popup.TOP_OFFSET + i - 1, 0, -1)
    end
    vim.api.nvim_buf_set_option(popup.buf, "modifiable", false)
end

local function goto_feature(ctx: FeatureContext, line: integer)
    local index = line - popup.TOP_OFFSET
    local crate = ctx.crate
    local version = ctx.version
    local hist_index = ctx.history_index
    local feature = ctx.history[hist_index].feature

    local selected_feature: Feature = nil
    if feature then
        local m = feature.members[index]
        if m then
            selected_feature = version.features:get_feat(m)
        end
    else
        selected_feature = version.features[index]
    end
    if not selected_feature then return end

    M.open_feature_details(ctx, crate, version, selected_feature, {
        focus = true,
        update = true,
    })

    -- update current entry
    local current = ctx.history[hist_index]
    current.line = line

    ctx.history_index = hist_index + 1
    hist_index = ctx.history_index
    for i=hist_index, #ctx.history, 1 do
        ctx.history[i] = nil
    end

    ctx.history[hist_index] = {
        feature = selected_feature,
        line = 3,
    }
end

local function jump_back_feature(ctx: FeatureContext,line: integer)
    local crate = ctx.crate
    local version = ctx.version
    local hist_index = ctx.history_index

    if hist_index == 1 then
        popup.hide()
        return
    end

    -- update current entry
    local current = ctx.history[hist_index]
    current.line = line

    ctx.history_index = hist_index - 1
    hist_index = ctx.history_index

    if hist_index == 1 then
        M.open_features(ctx, crate, version, {
            focus = true,
            line = ctx.history[1].line,
            update = true,
        })
    else
        local entry = ctx.history[hist_index]
        if not entry then return end

        M.open_feature_details(ctx, crate, version, entry.feature, {
            focus = true,
            line = entry.line,
            update = true,
        })
    end
end

local function jump_forward_feature(ctx: FeatureContext, line: integer)
    local crate = ctx.crate
    local version = ctx.version
    local hist_index = ctx.history_index

    if hist_index == #ctx.history then
        return
    end

    -- update current entry
    local current = ctx.history[hist_index]
    current.line = line

    ctx.history_index = hist_index + 1
    hist_index = ctx.history_index

    local entry = ctx.history[hist_index]
    if not entry then return end

    M.open_feature_details(ctx, crate, version, entry.feature, {
        focus = true,
        line = entry.line,
        update = true,
    })
end

local function config_feat_win(ctx: FeatureContext): function()
    return function()
        for _,k in ipairs(core.cfg.popup.keys.toggle_feature) do
            vim.api.nvim_buf_set_keymap(popup.buf, "n", k, "", {
                callback = function()
                    toggle_feature(ctx, vim.api.nvim_win_get_cursor(0)[1])
                end,
                noremap = true,
                silent = true,
                desc = "Toggle feature",
            })
        end

        for _,k in ipairs(core.cfg.popup.keys.goto_item) do
            vim.api.nvim_buf_set_keymap(popup.buf, "n", k, "", {
                callback = function()
                    goto_feature(ctx, vim.api.nvim_win_get_cursor(0)[1])
                end,
                noremap = true,
                silent = true,
                desc = "Goto feature",
            })
        end

        for _,k in ipairs(core.cfg.popup.keys.jump_forward) do
            vim.api.nvim_buf_set_keymap(popup.buf, "n", k, "", {
                callback = function()
                    jump_forward_feature(ctx, vim.api.nvim_win_get_cursor(0)[1])
                end,
                noremap = true,
                silent = true,
                desc = "Jump forward",
            })
        end

        for _,k in ipairs(core.cfg.popup.keys.jump_back) do
            vim.api.nvim_buf_set_keymap(popup.buf, "n", k, "", {
                callback = function()
                    jump_back_feature(ctx, vim.api.nvim_win_get_cursor(0)[1])
                end,
                noremap = true,
                silent = true,
                desc = "Jump back",
            })
        end
    end
end

function M.open_features(ctx: FeatureContext, crate: Crate, version: Version, opts: WinOpts)
    popup.type = "features"

    local features = version.features
    local title = string.format(core.cfg.popup.text.title, crate.name.." "..version.num)
    local feat_width = 0
    local features_text = {}

    local features_info = util.features_info(crate, features)
    for _,f in ipairs(features) do
        local hi_text = feature_text(features_info, f)
        table.insert(features_text, hi_text)
        feat_width = math.max(vim.fn.strdisplaywidth(hi_text.text) as integer, feat_width)
    end

    local width = popup.win_width(title, feat_width)
    local height = popup.win_height(features)

    if opts.update then
        popup.update_win(width, height, title, features_text, opts)
    else
        popup.open_win(width, height, title, features_text, opts, config_feat_win(ctx))
    end
end

function M.open_feature_details(ctx: FeatureContext, crate: Crate, version: Version, feature: Feature, opts: WinOpts)
    popup.type = "features"

    local features = version.features
    local members = feature.members
    local title = string.format(core.cfg.popup.text.title, crate.name.." "..version.num.." "..feature.name)
    local feat_width = 0
    local features_text = {}

    local features_info = util.features_info(crate, features)
    for _,m in ipairs(members) do
        local f = features:get_feat(m) or {
            name = m,
            members = {},
        }

        local hi_text = feature_text(features_info, f)
        table.insert(features_text, hi_text)
        feat_width = math.max(hi_text.text:len(), feat_width)
    end

    local width = popup.win_width(title, feat_width)
    local height = popup.win_height(members)

    if opts.update then
        popup.update_win(width, height, title, features_text, opts)
    else
        popup.open_win(width, height, title, features_text, opts, config_feat_win(ctx))
    end
end

function M.open(crate: Crate, version: Version, opts: WinOpts)
    local ctx = {
        buf = util.current_buf(),
        crate = crate,
        version = version,
        history = {
            { feature = nil, line = opts and opts.line or 3 },
        },
        history_index = 1,
    }
    M.open_features(ctx, crate, version, opts)
end

function M.open_details(crate: Crate, version: Version, feature: Feature, opts: WinOpts)
    local ctx = {
        buf = util.current_buf(),
        crate = crate,
        version = version,
        history = {
            { feature = nil, line = 3 } as FeatHistoryEntry,
            { feature = feature, line = opts and opts.line or 3 },
        },
        history_index = 2,
    }
    M.open_feature_details(ctx, crate, version, feature, opts)
end

return M
