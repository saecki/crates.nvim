---@class Popup
---@field buf integer|nil
---@field win integer|nil
---@field feat_ctx FeatureContext|nil

---@class FeatureContext
---@field buf integer
---@field crate Crate
---@field version Version
---@field history HistoryEntry[]

---@class HistoryEntry
---@field feature Feature|nil
---@field line integer -- 1 indexed

---@class WinOpts
---@field focus boolean
---@field line integer -- 1 indexed

---@class HighlightText
---@field text string
---@field hi string

---@type Popup
local M = {}

local core = require('crates.core')
local toml = require('crates.toml')
local Crate = toml.Crate
local util = require('crates.util')
local Range = require('crates.types').Range

local top_offset = 2

function M.show()
    if M.win and vim.api.nvim_win_is_valid(M.win) then
        M.focus()
        return
    end

    local pos = vim.api.nvim_win_get_cursor(0)
    local line = pos[1] - 1
    local col = pos[2]

    local crates = util.get_lines_crates(Range.new(line, line + 1))
    if not crates or not crates[1] or not crates[1].versions then
        return
    end
    local crate = crates[1].crate
    local versions = crates[1].versions

    local avoid_pre = core.cfg.avoid_prerelease and not crate.req_has_suffix
    local newest = util.get_newest(versions, avoid_pre, crate.reqs)

    local function show_features()
        local feature = nil
        for _,cf in ipairs(crate.feats) do
            if cf.decl_col:contains(col - crate.feat_col.s) then
                feature = newest.features:get_feat(cf.name)
                break
            end
        end

        if feature then
            M.show_feature_details(crate, newest, feature)
        else
            M.show_features(crate, newest)
        end
    end

    local function show_default_features()
        local default_feature = newest.features:get_feat("default") or {
            name = "default",
            members = {},
        }

        M.show_feature_details(crate, newest, default_feature)
    end

    if crate.syntax == "plain" then
        M.show_versions(crate, versions)
    elseif crate.syntax == "table" then
        if line == crate.feat_line then
            show_features()
        elseif line == crate.def_line then
            show_default_features()
        else
            M.show_versions(crate, versions)
        end
    elseif crate.syntax == "inline_table" then
        if crate.feat_text and line == crate.feat_line and crate.feat_decl_col:contains(col) then
            show_features()
        elseif crate.def_text and line == crate.def_line and crate.def_decl_col:contains(col) then
            show_default_features()
        else
            M.show_versions(crate, versions)
        end
    end
end

---@param line integer
function M.focus(line)
    if M.win and vim.api.nvim_win_is_valid(M.win) then
        vim.api.nvim_set_current_win(M.win)
        local l = math.min(line or 3, vim.api.nvim_buf_line_count(M.buf))
        vim.api.nvim_win_set_cursor(M.win, { l, 0 })
    end
end

function M.hide()
    if M.win and vim.api.nvim_win_is_valid(M.win) then
        vim.api.nvim_win_close(M.win, false)
    end
    M.win = nil

    if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
        vim.api.nvim_buf_delete(M.buf, {})
    end
    M.buf = nil
end

---@param width integer
---@param height integer
local function create_win(width, height)
    -- create window
    local opts = {
        relative = "cursor",
        col = 0,
        row = 1,
        width = width,
        height = height,
        style = core.cfg.popup.style,
        border = core.cfg.popup.border,
    }
    M.win = vim.api.nvim_open_win(M.buf, false, opts)
end

---@param width integer
---@param height integer
---@param title string
---@param text HighlightText[]
---@param opts WinOpts
---@param configure fun()
local function show_win(width, height, title, text, opts, configure)
    M.buf = vim.api.nvim_create_buf(false, true)
    local namespace_id = vim.api.nvim_create_namespace("crates.nvim.popup")

    -- add text and highlights
    vim.api.nvim_buf_set_lines(M.buf, 0, 2, false, { title, "" })
    vim.api.nvim_buf_add_highlight(M.buf, namespace_id, core.cfg.popup.highlight.title, 0, 0, -1)

    for i,v in ipairs(text) do
        vim.api.nvim_buf_set_lines(M.buf, top_offset + i - 1, top_offset + i, false, { v.text })
        vim.api.nvim_buf_add_highlight(M.buf, namespace_id, v.hi, top_offset + i - 1, 0, -1)
    end

    vim.api.nvim_buf_set_option(M.buf, "modifiable", false)

    -- create window
    create_win(width, height)

    -- add key mappings
    local hide_cmd = ":lua require('crates.popup').hide()<cr>"
    for _,k in ipairs(core.cfg.popup.keys.hide) do
        vim.api.nvim_buf_set_keymap(M.buf, "n", k, hide_cmd, { noremap = true, silent = true })
    end

    if configure then
        configure()
    end

    -- autofocus
    if opts and opts.focus or core.cfg.popup.autofocus then
        M.focus(opts and opts.line)
    end
end


---@param crate Crate
---@param versions Version[]
---@param opts WinOpts
function M.show_versions(crate, versions, opts)
    local title = string.format(core.cfg.popup.text.title, crate.name)
    local num_versions = #versions
    local height = math.min(core.cfg.popup.max_height, num_versions + top_offset)
    local width = 0
    local versions_text = {}

    for _,v in ipairs(versions) do
        local text, hi
        if v.yanked then
            text = string.format(core.cfg.popup.text.yanked, v.num)
            hi = core.cfg.popup.highlight.yanked
        elseif v.parsed.suffix then
            text = string.format(core.cfg.popup.text.prerelease, v.num)
            hi = core.cfg.popup.highlight.prerelease
        else
            text = string.format(core.cfg.popup.text.version, v.num)
            hi = core.cfg.popup.highlight.version
        end


        table.insert(versions_text, { text = text, hi = hi })
        width = math.max(vim.fn.strdisplaywidth(text), width)
    end

    if core.cfg.popup.version_date then
        local orig_width = width

        for i,v in ipairs(versions_text) do
            local diff = orig_width - vim.fn.strdisplaywidth(v.text)
            local date_text = string.format(core.cfg.popup.text.date, versions[i].created:display())
            v.text = v.text..string.rep(" ", diff)..date_text

            width = math.max(vim.fn.strdisplaywidth(v.text), orig_width)
        end
    end

    width = math.max(width, core.cfg.popup.min_width, vim.fn.strdisplaywidth(title))


    show_win(width, height, title, versions_text, opts, function()
        local select_cmd = string.format(
            ":lua require('crates.popup').select_version(%d, '%s', %s - %d)<cr>",
            util.current_buf(),
            crate.name,
            "vim.api.nvim_win_get_cursor(0)[1]",
            top_offset
        )
        for _,k in ipairs(core.cfg.popup.keys.select) do
            vim.api.nvim_buf_set_keymap(M.buf, "n", k, select_cmd, { noremap = true, silent = true })
        end

        local select_dumb_cmd = string.format(
            ":lua require('crates.popup').select_version(%d, '%s', %s - %d, false)<cr>",
            util.current_buf(),
            crate.name,
            "vim.api.nvim_win_get_cursor(0)[1]",
            top_offset
        )
        for _,k in ipairs(core.cfg.popup.keys.select_dumb) do
            vim.api.nvim_buf_set_keymap(M.buf, "n", k, select_dumb_cmd, { noremap = true, silent = true })
        end

        local copy_cmd = string.format(
            ":lua require('crates.popup').copy_version('%s', %s - %d)<cr>",
            crate.name,
            "vim.api.nvim_win_get_cursor(0)[1]",
            top_offset
        )
        for _,k in ipairs(core.cfg.popup.keys.copy_version) do
            vim.api.nvim_buf_set_keymap(M.buf, "n", k, copy_cmd, { noremap = true, silent = true })
        end
    end)
end

---@param buf integer
---@param name string
---@param index integer
---@param smart boolean | nil
function M.select_version(buf, name, index, smart)
    local crates = core.crate_cache[buf]
    if not crates then return end

    local crate = crates[name]
    if not crate or not crate.reqs then return end

    local versions = core.vers_cache[name]
    if not versions then return end

    if index <= 0 or index > #versions then
        return
    end
    local version = versions[index]

    if smart == nil then
        smart = core.cfg.smart_insert
    end

    if smart then
        util.set_version_smart(buf, crate, version.parsed)
    else
        util.set_version(buf, crate, version.num)
    end

    -- update crate position
    local line = vim.api.nvim_buf_get_lines(buf, crate.req_line, crate.req_line + 1, false)[1]
    local c = nil
    if crate.syntax == "table" then
        c = toml.parse_crate_table_req(line)
    elseif crate.syntax == "plain" then
        c = toml.parse_crate(line)
    elseif crate.syntax == "inline_table" then
        c = toml.parse_crate(line)
    end
    if c then
        crate.req_col = c.req_col
    end
end

---@param name string
---@param index integer
function M.copy_version(name, index)
    local versions = core.vers_cache[name]
    if not versions then return end

    if index <= 0 or index > #versions then
        return
    end
    local text = versions[index].num

    vim.fn.setreg(core.cfg.popup.copy_register, text)
end


---@param crate Crate
---@param features Features
---@param feature Feature
---@return HighlightText
local function feature_text(crate, features, feature)
    local text, hi
    local enabled, transitive = util.is_feat_enabled(crate, features, feature.name)
    if enabled then
        text = string.format(core.cfg.popup.text.enabled, feature.name)
        hi = core.cfg.popup.highlight.enabled
    elseif transitive then
        text = string.format(core.cfg.popup.text.transitive, feature.name)
        hi = core.cfg.popup.highlight.transitive
    else
        text = string.format(core.cfg.popup.text.feature, feature.name)
        hi = core.cfg.popup.highlight.feature
    end
    return { text = text, hi = hi }
end

---@param crate Crate
---@param version Version
---@param opts WinOpts
function M.show_features(crate, version, opts)
    M.feat_ctx = {
        buf = util.current_buf(),
        crate = crate,
        version = version,
        history = {},
    }
    M._show_features(crate, version, opts)
end

---@param crate Crate
---@param version Version
---@param opts WinOpts
function M._show_features(crate, version, opts)
    local features = version.features
    local title = string.format(core.cfg.popup.text.title, crate.name.." "..version.num)
    local num_feats = #features
    local height = math.min(core.cfg.popup.max_height, num_feats + top_offset)
    local width = math.max(core.cfg.popup.min_width, title:len())
    local features_text = {}

    for _,f in ipairs(features) do
        local hi_text = feature_text(crate, features, f)
        table.insert(features_text, hi_text)
        width = math.max(hi_text.text:len(), width)
    end

    show_win(width, height, title, features_text, opts, function()
        local toggle_cmd = string.format(
            ":lua require('crates.popup').toggle_feature(%d, nil, %s - %d)<cr>",
            util.current_buf(),
            "vim.api.nvim_win_get_cursor(0)[1]",
            top_offset
        )
        for _,k in ipairs(core.cfg.popup.keys.toggle_feature) do
            vim.api.nvim_buf_set_keymap(M.buf, "n", k, toggle_cmd, { noremap = true, silent = true })
        end

        local goto_cmd = string.format(
            ":lua require('crates.popup').goto_feature(nil, %s - %d)<cr>",
            "vim.api.nvim_win_get_cursor(0)[1]",
            top_offset
        )
        for _,k in ipairs(core.cfg.popup.keys.goto_feature) do
            vim.api.nvim_buf_set_keymap(M.buf, "n", k, goto_cmd, { noremap = true, silent = true })
        end

        local goback_cmd = ":lua require('crates.popup').goback_feature()<cr>"
        for _,k in ipairs(core.cfg.popup.keys.goback_feature) do
            vim.api.nvim_buf_set_keymap(M.buf, "n", k, goback_cmd, { noremap = true, silent = true })
        end
    end)
end

---@param crate Crate
---@param version Version
---@param feature Feature
---@param opts WinOpts
function M.show_feature_details(crate, version, feature, opts)
    M.feat_ctx = {
        buf = util.current_buf(),
        crate = crate,
        version = version,
        history = { { feature = nil, line = 3 } },
    }
    M._show_feature_details(crate, version, feature, opts)
end

---@param crate Crate
---@param version Version
---@param feature Feature
---@param opts WinOpts
function M._show_feature_details(crate, version, feature, opts)
    local features = version.features
    local members = feature.members
    local title = string.format(core.cfg.popup.text.title, crate.name.." "..version.num.." "..feature.name)
    local num_members = #members
    local height = math.min(core.cfg.popup.max_height, num_members + top_offset)
    local width = math.max(core.cfg.popup.min_width, title:len())
    local features_text = {}

    for _,m in ipairs(members) do
        local f = features:get_feat(m) or {
            name = m,
            members = {},
        }

        local hi_text = feature_text(crate, features, f)
        table.insert(features_text, hi_text)
        width = math.max(hi_text.text:len(), width)
    end

    show_win(width, height, title, features_text, opts, function()
        local toggle_cmd = string.format(
            ":lua require('crates.popup').toggle_feature(%d, '%s', %s - %d)<cr>",
            util.current_buf(),
            feature.name,
            "vim.api.nvim_win_get_cursor(0)[1]",
            top_offset
        )
        for _,k in ipairs(core.cfg.popup.keys.toggle_feature) do
            vim.api.nvim_buf_set_keymap(M.buf, "n", k, toggle_cmd, { noremap = true, silent = true })
        end

        local goto_cmd = string.format(
            ":lua require('crates.popup').goto_feature('%s', %s - %d)<cr>",
            feature.name,
            "vim.api.nvim_win_get_cursor(0)[1]",
            top_offset
        )
        for _,k in ipairs(core.cfg.popup.keys.goto_feature) do
            vim.api.nvim_buf_set_keymap(M.buf, "n", k, goto_cmd, { noremap = true, silent = true })
        end

        local goback_cmd = ":lua require('crates.popup').goback_feature()<cr>"
        for _,k in ipairs(core.cfg.popup.keys.goback_feature) do
            vim.api.nvim_buf_set_keymap(M.buf, "n", k, goback_cmd, { noremap = true, silent = true })
        end
    end)
end

---@param buf integer
---@param feature_name string|nil
---@param index integer
function M.toggle_feature(buf, feature_name, index)
    if not M.feat_ctx then return end

    local crate = M.feat_ctx.crate
    local version = M.feat_ctx.version
    if not crate or not version then return end

    local feature = nil
    local selected_feature = nil
    if feature_name then
        feature = version.features:get_feat(feature_name)
        if feature then
            local m = feature.members[index]
            if m then
                selected_feature = version.features:get_feat(m)
            end
        end
    else
        selected_feature = version.features[index]
    end
    if not selected_feature then return end

    local crate_feature = crate:get_feat(selected_feature.name)
    local l = nil
    if crate_feature then
        util.remove_feature(buf, crate, crate_feature)
        l = crate.feat_line
    else
        l = util.add_feature(buf, crate, selected_feature)
    end
    local line = vim.api.nvim_buf_get_lines(buf, l, l + 1, false)[1]
    local c = nil
    if crate.syntax == "table" then
        c = toml.parse_crate_table_feat(line)
    elseif crate.syntax == "plain" then
        c = toml.parse_crate(line)
    elseif crate.syntax == "inline_table" then
        c = toml.parse_crate(line)
    end
    if c then
        c.feats = toml.parse_crate_features(c.feat_text)
        M.feat_ctx.crate = Crate.new(vim.tbl_extend("force", crate, c))
    end

    M.hide()
    local opts = {
        focus = true,
        line = index + top_offset,
    }
    if feature then
        M.show_feature_details(M.feat_ctx.crate, version, feature, opts)
    else
        M.show_features(M.feat_ctx.crate, version, opts)
    end
end

---@param feature_name string|nil
---@param index integer
function M.goto_feature(feature_name, index)
    if not M.feat_ctx then return end

    local crate = M.feat_ctx.crate
    local version = M.feat_ctx.version
    if not crate or not version then return end

    local feature = nil
    local selected_feature = nil
    if feature_name then
        feature = version.features:get_feat(feature_name)
        if feature then
            local m = feature.members[index]
            if m then
                selected_feature = version.features:get_feat(m)
            end
        end
    else
        selected_feature = version.features[index]
    end
    if not selected_feature then return end

    M.hide()
    M._show_feature_details(crate, version, selected_feature, { focus = true })

    table.insert(M.feat_ctx.history, {
        feature = feature,
        line = index + top_offset,
    })
end

function M.goback_feature()
    if not M.feat_ctx then return end

    local crate = M.feat_ctx.crate
    local version = M.feat_ctx.version

    local hist_count = #M.feat_ctx.history
    if hist_count == 0 then
        M.hide()
        return
    end

    if hist_count == 1 then
        M.hide()
        M._show_features(crate, version, {
            focus = true,
            line = M.feat_ctx.history[1].line,
        })
    else
        local entry = M.feat_ctx.history[hist_count]
        if not entry then return end

        M.hide()
        M._show_feature_details(crate, version, entry.feature, {
            focus = true,
            line = entry.line,
        })
    end

    M.feat_ctx.history[#M.feat_ctx.history] = nil
end

return M
