local M = {}

local C = require('crates')

function M.show_versions()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local crate = nil

    local filepath = C.get_filepath()
    local crates = C.crate_cache[filepath]
    if crates then
        for _,c in pairs(crates) do
            if c.linenr + 1 == row then
                crate = c
            end
        end
    end
    if not crate then
        return
    end

    local versions = C.vers_cache[crate.name]
    if not versions then
        return
    end

    local num_versions = vim.tbl_count(versions)
    local height = math.min(C.config.popup.max_height, num_versions)

    local width = C.config.popup.min_width
    local versions_text = {}
    local yanked_highlights = {}
    for i,v in ipairs(versions) do
        local vers_text = v.num
        if v.yanked then
            local c_start = string.len(vers_text) + 1
            local c_end = c_start + string.len(C.config.popup.text.yanked)
            table.insert(yanked_highlights, { line = i - 1, col_start = c_start, col_end = c_end })

            vers_text = vers_text .. " " .. C.config.popup.text.yanked
        end

        table.insert(versions_text, vers_text)
        width = math.max(string.len(vers_text), width)
    end

    local top_offset = 2
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
            C.config.popup.highlight.yanked,
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
        style = C.config.popup.style,
        border = C.config.popup.border,
    }
    local win = vim.api.nvim_open_win(buf, true, opts)

    -- add key mappings
    local close_cmd = string.format("lua require('crates.popup').hide_versions(%d)", win)
    for _,k in ipairs(C.config.popup.keys.hide) do
        vim.api.nvim_buf_set_keymap(buf, "n", k, string.format(":%s<cr>", close_cmd), { noremap = true, silent = true })
    end
    
    for _,k in ipairs(C.config.popup.keys.copy_version) do
        vim.api.nvim_buf_set_keymap(buf, "n", k, "_yE", { noremap = true, silent = true })
    end

    -- show window
    vim.api.nvim_win_set_cursor(win, { 3, 0 })

    -- automatically hide window
    vim.cmd("augroup CratesPopup"..win)
    vim.cmd("autocmd BufLeave,WinLeave * "..close_cmd)
    vim.cmd("augroup END")

    return win
end

function M.hide_versions(win)
    if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
    end
end

return M
