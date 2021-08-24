local M = {}

local job = require("plenary.job")
local toml = require("crates.toml")
local config_manager = require("crates.config")

local api = "https://crates.io/api/v1"

M.vers_cache = {}
M.crate_cache = {}
M.running_jobs = {}
M.visible = false

local function get_filepath()
    return vim.fn.expand("%:p")
end

function M.fetch_crate_versions(name, callback)
    local url = string.format("%s/crates/%s/versions", api, name)

    local function on_exit(j, code, _)
        local resp = table.concat(j:result(), "\n")
        if code ~= 0 then
            resp = nil
        end

        local function cb()
            callback(resp)
        end

        if M.visible then
            vim.schedule(cb)
        end

        M.running_jobs[name] = nil
    end

    local j = job:new {
        command = "curl",
        args = { url },
        on_exit = on_exit,
    }

    M.running_jobs[name] = j

    j:start()
end

function M.display_version(crate, versions)
    if not M.visible then
        return
    end

    local display_vers = versions and versions[1] or nil
    local virt_text
    if display_vers then
        virt_text = { { string.format(M.config.text.version, display_vers), M.config.highlight.version } }
    else
        virt_text = { { M.config.text.error, M.config.highlight.error } }
    end

    vim.api.nvim_buf_clear_namespace(0, M.namespace_id, crate.linenr, crate.linenr + 1)
    vim.api.nvim_buf_set_virtual_text(0, M.namespace_id, crate.linenr, virt_text, {})
end

function M.display_loading(crate)
    local virt_text = { { M.config.text.loading, M.config.highlight.loading } }
    vim.api.nvim_buf_clear_namespace(0, M.namespace_id, crate.linenr, crate.linenr + 1)
    vim.api.nvim_buf_set_virtual_text(0, M.namespace_id, crate.linenr, virt_text, {})
end

function M.reload_crate(crate)
    local function on_fetched(resp)
        local data = vim.fn.json_decode(resp)

        local versions = {}
        if data and data.versions then
            for _,v in ipairs(data.versions) do
                if v.num then
                    table.insert(versions, v.num)
                end
            end
        end

        if versions and versions[1] then
            M.vers_cache[crate.name] = versions
        end

        M.display_version(crate, versions)
    end

    if M.config.loading_indicator then
        M.display_loading(crate)
    end

    M.fetch_crate_versions(crate.name, on_fetched)
end

function M._clear()
    for n,j in pairs(M.running_jobs) do
        j.on_exit = nil
        j:shutdown(0, 2)
        M.running_jobs[n] = nil
    end

    if M.namespace_id then
        vim.api.nvim_buf_clear_namespace(0, M.namespace_id, 0, -1)
    end
    M.namespace_id = vim.api.nvim_create_namespace("crates.nvim")
end

function M.clear()
    M.visible = false
    M._clear()
end

function M.reload()
    M.visible = true
    M.vers_cache = {}
    M._clear()
    
    local filepath = get_filepath()
    local crates = toml.parse_crates()
    
    M.crate_cache[filepath] = {}

    for _,c in ipairs(crates) do
        M.crate_cache[filepath][c.name] = c
        M.reload_crate(c)
    end
end

function M.update()
    M.visible = true
    M._clear()

    local filepath = get_filepath()
    local crates = toml.parse_crates()

    M.crate_cache[filepath] = {}

    for _,c in ipairs(crates) do
        local versions = M.vers_cache[c.name]

        M.crate_cache[filepath][c.name] = c

        if versions then
            M.display_version(c, versions)
        else
            M.reload_crate(c)
        end
    end
end

function M.toggle()
    if M.visible then
        M.clear()
    else
        M.update()
    end
end

function M.show_versions_popup()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local crate = nil

    local filepath = get_filepath()
    local crates = M.crate_cache[filepath]
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

    local versions = M.vers_cache[crate.name]
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
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)

    local opts = {
        relative = "cursor",
        col = 0,
        row = 1,
        width = width,
        height = height,
        style = M.config.win_style,
        border = M.config.win_border,
    }
    local win = vim.api.nvim_open_win(buf, true, opts)

    local close_cmd = string.format("lua require('crates').hide_versions_popup(%d)", win)
    for _,k in ipairs(M.config.popup_hide_keys) do
        vim.api.nvim_buf_set_keymap(buf, "n", k, string.format(":%s<cr>", close_cmd), { noremap = true, silent = true })
    end

    vim.cmd("augroup CratesPopup"..win)
    vim.cmd("autocmd BufLeave,WinLeave *"..close_cmd)
    vim.cmd("augroup END")

    return win
end

function M.hide_versions_popup(win)
    if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
    end
end

function M.setup(config)
    if config then
        config_manager.extend_with_default(config)
        M.config = config
    else
        M.config = config_manager.default()
    end

    vim.cmd("augroup Crates")
    if M.config.autoload then
        vim.cmd("autocmd BufRead Cargo.toml lua require('crates').update()")
    end
    if M.config.autoupdate then
        vim.cmd("autocmd TextChanged,TextChangedI,TextChangedP Cargo.toml lua require('crates').update()")
    end
    vim.cmd("augroup END")
end

return M
