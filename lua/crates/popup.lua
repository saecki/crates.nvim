local M = {}

local core = require('crates.core')
local util = require('crates.util')
local toml = require('crates.toml')

local top_offset = 2

function M.show_versions()
    if M.win and vim.api.nvim_win_is_valid(M.win) then
        M.focus_versions()
        return
    end

    local linenr = vim.api.nvim_win_get_cursor(0)[1]
    local crates = util.get_lines_crates({ s = linenr - 1, e = linenr })
    if not crates or not crates[1] then
        return
    end
    local crate = crates[1].crate
    local versions = crates[1].versions
    if not versions then return end

    local title_text = string.format(core.cfg.popup.text.title, crate.name)
    local num_versions = vim.tbl_count(versions)
    local height = math.min(core.cfg.popup.max_height, num_versions + top_offset)
    local width = math.max(core.cfg.popup.min_width, string.len(title_text))
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
        width = math.max(string.len(text), width)
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
    local hide_cmd = ":lua require('crates.popup').hide_versions()<cr>"
    for _,k in ipairs(core.cfg.popup.keys.hide) do
        vim.api.nvim_buf_set_keymap(M.buf, "n", k, hide_cmd, { noremap = true, silent = true })
    end

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
        M.focus_versions()
    end
end

function M.focus_versions()
    if M.win and vim.api.nvim_win_is_valid(M.win) then
        vim.api.nvim_set_current_win(M.win)
        vim.api.nvim_win_set_cursor(M.win, { 3, 0 })
    end
end

function M.hide_versions()
    if M.win and vim.api.nvim_win_is_valid(M.win) then
        vim.api.nvim_win_close(M.win, false)
        M.win = nil
    end
    if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
        vim.api.nvim_buf_delete(M.buf, {})
        M.buf = nil
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
    if not crate then return end

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
    local line = vim.api.nvim_buf_get_lines(buf, crate.vers_line, crate.vers_line + 1, false)[1]
    local c = nil
    if crate.syntax == "section" then
        c = toml.parse_crate_dep_section_line(line)
    elseif crate.syntax == "normal" then
        c = toml.parse_dep_section_line(line)
    elseif crate.syntax == "map" then
        c = toml.parse_dep_section_line(line)
    end
    if c then
        crate.col = c.col
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

return M
