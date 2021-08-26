local M = {}

local core = require('crates.core')
local util = require('crates.util')

function M.show_versions()
    -- hide if still open
    M.hide_versions()

    local top_offset = 2
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
    M.win_id = vim.api.nvim_open_win(buf, true, opts)

    -- add key mappings
    local close_cmd = "lua require('crates.popup').hide_versions()"
    for _,k in ipairs(core.cfg.popup.keys.hide) do
        vim.api.nvim_buf_set_keymap(buf, "n", k, string.format(":%s<cr>", close_cmd), { noremap = true, silent = true })
    end

    for _,k in ipairs(core.cfg.popup.keys.copy_version) do
        vim.api.nvim_buf_set_keymap(buf, "n", k, "_yE", { noremap = true, silent = true })
    end

    -- show window
    vim.api.nvim_win_set_cursor(M.win_id, { 3, 0 })

    -- automatically hide window
    vim.cmd("augroup CratesPopup" .. M.win_id)
    vim.cmd("autocmd BufLeave,WinLeave * "..close_cmd)
    vim.cmd("augroup END")
end

function M.hide_versions()
    if M.win_id and vim.api.nvim_win_is_valid(M.win_id) then
        vim.api.nvim_win_close(M.win_id, false)
    end
end

return M
