local M = {}

local core = require('crates.core')
local toml = require('crates.toml')
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
    local col = pos [2] + 1

    local crates = util.get_lines_crates(Range.new(line, line + 1))
    if not crates or not crates[1] or not crates[1].versions then
        return
    end
    local crate = crates[1].crate
    local versions = crates[1].versions

    local avoid_pre = core.cfg.avoid_prerelease and not crate.req_has_suffix
    local newest = util.get_newest(versions, avoid_pre, crate.reqs)

    if crate.syntax == "normal" then
        M.show_versions(crate, versions)
    elseif crate.syntax == "table" then
        if line == crate.req_line then
            M.show_versions(crate, versions)
        elseif line == crate.feat_line then
            M.show_features(crate, newest)
        end
    elseif crate.syntax == "inline_table" then
        if crate.req_text and line == crate.req_line and crate.req_decl_col:contains(col) then
            M.show_versions(crate, versions)
        elseif crate.feat_text and line == crate.feat_line and crate.feat_decl_col:contains(col) then
            M.show_features(crate, newest)
        end
    end
end

function M.focus()
    if M.win and vim.api.nvim_win_is_valid(M.win) then
        vim.api.nvim_set_current_win(M.win)
        vim.api.nvim_win_set_cursor(M.win, { 3, 0 })
    end
end

function M.hide()
    if M.win and vim.api.nvim_win_is_valid(M.win) then
        vim.api.nvim_win_close(M.win, false)
        M.win = nil
    end
    if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
        vim.api.nvim_buf_delete(M.buf, {})
        M.buf = nil
    end
end


---@param crate Crate
---@param versions Version[]
function M.show_versions(crate, versions)
    local title_text = string.format(core.cfg.popup.text.title, crate.name)
    local num_versions = vim.tbl_count(versions)
    local height = math.min(core.cfg.popup.max_height, num_versions + top_offset)
    local width = math.max(core.cfg.popup.min_width, title_text:len())
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
        width = math.max(text:len(), width)
    end

    M.buf = vim.api.nvim_create_buf(false, true)
    local namespace_id = vim.api.nvim_create_namespace("crates.nvim.popup")

    -- add text and highlights
    vim.api.nvim_buf_set_lines(M.buf, 0, 2, false, { title_text, "" })
    vim.api.nvim_buf_add_highlight(M.buf, namespace_id, core.cfg.popup.highlight.title, 0, 0, -1)

    for i,v in ipairs(versions_text) do
        vim.api.nvim_buf_set_lines(M.buf, top_offset + i - 1, top_offset + i, false, { v.text })
        vim.api.nvim_buf_add_highlight(M.buf, namespace_id, v.hi, top_offset + i - 1, 0, -1)
    end

    vim.api.nvim_buf_set_option(M.buf, "modifiable", false)

    -- create window
    M.create_win(width, height)

    -- add key mappings
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

    -- autofocus
    if core.cfg.popup.autofocus then
        M.focus()
    end
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

    if index <= 0 or index > vim.tbl_count(versions) then
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
    elseif crate.syntax == "normal" then
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

    if index <= 0 or index > vim.tbl_count(versions) then
        return
    end
    local text = versions[index].num

    vim.fn.setreg(core.cfg.popup.copy_register, text)
end


---@param crate Crate
---@param version Version
function M.show_features(crate, version)
    local features = version.features
    local title_text = string.format(core.cfg.popup.text.title, crate.name.." "..version.num)
    local num_versions = vim.tbl_count(features)
    local height = math.min(core.cfg.popup.max_height, num_versions + top_offset)
    local width = math.max(core.cfg.popup.min_width, title_text:len())
    local features_text = {}

    for _,f in ipairs(features) do
        local text = string.format(core.cfg.popup.text.feature, f.name)
        local hi = core.cfg.popup.highlight.feature
        table.insert(features_text, { text = text, hi = hi })
        width = math.max(text:len(), width)
    end

    M.buf = vim.api.nvim_create_buf(false, true)
    local namespace_id = vim.api.nvim_create_namespace("crates.nvim.popup")

    -- add text and highlights
    vim.api.nvim_buf_set_lines(M.buf, 0, 2, false, { title_text, "" })
    vim.api.nvim_buf_add_highlight(M.buf, namespace_id, core.cfg.popup.highlight.title, 0, 0, -1)

    for i,v in ipairs(features_text) do
        vim.api.nvim_buf_set_lines(M.buf, top_offset + i - 1, top_offset + i, false, { v.text })
        vim.api.nvim_buf_add_highlight(M.buf, namespace_id, v.hi, top_offset + i - 1, 0, -1)
    end

    vim.api.nvim_buf_set_option(M.buf, "modifiable", false)

    -- create window
    M.create_win(width, height)

    -- autofocus
    if core.cfg.popup.autofocus then
        M.focus()
    end
end

---@param width integer
---@param height integer
function M.create_win(width, height)
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

    -- add key mappings
    local hide_cmd = ":lua require('crates.popup').hide()<cr>"
    for _,k in ipairs(core.cfg.popup.keys.hide) do
        vim.api.nvim_buf_set_keymap(M.buf, "n", k, hide_cmd, { noremap = true, silent = true })
    end

end

return M
