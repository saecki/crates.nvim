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
    local height = math.min(20, num_versions)

    local width = 20
    for _,v in ipairs(versions) do
        width = math.max(string.len(v), width)
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, num_versions, false, versions)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

    local opts = {
        relative = "cursor",
        col = 0,
        row = 1,
        width = width,
        height = height,
        style = C.config.win_style,
        border = C.config.win_border,
    }
    local win = vim.api.nvim_open_win(buf, true, opts)

    local close_cmd = string.format("lua require('crates.popup').hide_versions(%d)", win)
    for _,k in ipairs(C.config.popup.keys.hide) do
        vim.api.nvim_buf_set_keymap(buf, "n", k, string.format(":%s<cr>", close_cmd), { noremap = true, silent = true })
    end
    
    for _,k in ipairs(C.config.popup.keys.copy_version) do
        vim.api.nvim_buf_set_keymap(buf, "n", k, "0yg_", { noremap = true, silent = true })
    end

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
