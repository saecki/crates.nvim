local M = {}

local core = require('crates.core')
local util = require('crates.util')
local toml = require('crates.toml')

local top_offset = 2

function M.show_versions()
    if M.win_id and vim.api.nvim_win_is_valid(M.win_id) then
        M.focus_versions()
        return
    end

    local linenr = vim.api.nvim_win_get_cursor(0)[1]
    local crate, versions = util.get_line_crate(linenr)

    if not crate or not versions then
        return
    end

    local num_versions = vim.tbl_count(versions)
    local height = math.min(core.cfg.popup.max_height, num_versions + top_offset)

    local width = core.cfg.popup.min_width
    local versions_text = {}
    local yanked_highlights = {}
    for i,v in ipairs(versions) do
        local vers_text = v.num
        if v.yanked then
            local c_start = string.len(vers_text) + 1
            local c_end = c_start + string.len(core.cfg.popup.text.yanked)
            table.insert(yanked_highlights, { line = i - 1, col_start = c_start, col_end = c_end })

            vers_text = vers_text .. " " .. core.cfg.popup.text.yanked
        end

        table.insert(versions_text, vers_text)
        width = math.max(string.len(vers_text), width)
    end

    local buf = vim.api.nvim_create_buf(false, true)
    local namespace_id = vim.api.nvim_create_namespace("crates.nvim.popup")

    -- add text and highlights
    vim.api.nvim_buf_set_lines(buf, 0, 2, false, { string.format("# %s", crate.name), "" })
    vim.api.nvim_buf_add_highlight(buf, namespace_id, "Special", 0, 0, 1)
    vim.api.nvim_buf_add_highlight(buf, namespace_id, "Title", 0, 2, -1)

    vim.api.nvim_buf_set_lines(buf, top_offset, num_versions + top_offset, false, versions_text)
    for _,h in ipairs(yanked_highlights) do
        vim.api.nvim_buf_add_highlight(
            buf,
            namespace_id,
            core.cfg.popup.highlight.yanked,
            h.line + top_offset,
            h.col_start,
            h.col_end
        )
    end

    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_buf_set_name(buf, "crates.popup"..buf)

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
    M.win_id = vim.api.nvim_open_win(buf, false, opts)

    -- add key mappings
    local hide_cmd = ":lua require('crates.popup').hide_versions()<cr>"
    for _,k in ipairs(core.cfg.popup.keys.hide) do
        vim.api.nvim_buf_set_keymap(buf, "n", k, hide_cmd, { noremap = true, silent = true })
    end

    local select_cmd = string.format(
        ":lua require('crates.popup').select_version(%d, '%s', %s - %d)<cr>",
        util.current_buf(),
        crate.name,
        "vim.api.nvim_win_get_cursor(0)[1]",
        top_offset
    )
    for _,k in ipairs(core.cfg.popup.keys.select) do
        vim.api.nvim_buf_set_keymap(buf, "n", k, select_cmd, { noremap = true, silent = true })
    end

    for _,k in ipairs(core.cfg.popup.keys.copy_version) do
        vim.api.nvim_buf_set_keymap(buf, "n", k, "_yE", { noremap = true, silent = true })
    end

    -- autofocus
    if core.cfg.autofocus then
        M.focus_versions()
    end
end

function M.focus_versions()
    if M.win_id and vim.api.nvim_win_is_valid(M.win_id) then
        vim.api.nvim_set_current_win(M.win_id)
        vim.api.nvim_win_set_cursor(M.win_id, { 3, 0 })
    end
end

function M.hide_versions()
    if M.win_id and vim.api.nvim_win_is_valid(M.win_id) then
        vim.api.nvim_win_close(M.win_id, false)
        M.win_id = nil
    end
end

function M.select_version(buf, name, index)
    local crates = core.crate_cache[buf]
    if not crates then return end

    local crate = crates[name]
    if not crate then return end

    local versions = core.vers_cache[name]
    if not versions then return end

    if index <= 0 or index > vim.tbl_count(versions) then
        return
    end
    local text = versions[index].num

    util.set_version(buf, crate, text)

    -- update crate position
    core.crate_cache[buf] = {}
    local parsed_crates = toml.parse_crates(buf)
    for _,c in ipairs(parsed_crates) do
        core.crate_cache[buf][c.name] = c
    end
end

return M
