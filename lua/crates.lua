local M = {}

local job = require("plenary.job")
local toml = require("crates.toml")
local config_manager = require("crates.config")

local api = "https://crates.io/api/v1"

M.cache = {}
M.running_jobs = {}
M.visible = false

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

function M.display_version(crate)
    if not M.visible then
        return
    end

    local display_vers = crate.available_versions and crate.available_versions[1] or nil
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
            crate.available_versions = versions
            M.cache[crate.name] = crate
        end

        M.display_version(crate)
    end

    if M.config.loading_indicator then
        M.display_loading(crate)
    end

    M.fetch_crate_versions(crate.name, on_fetched)
end

function M._clear()
    for n,j in pairs(M.running_jobs) do
        j.on_exit = nil
        j:shutdown(0, 9)
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
    M.cache = {}
    M._clear()

    local crates = toml.parse_crates()

    for _,c in ipairs(crates) do
        M.reload_crate(c)
    end
end

function M.update()
    M.visible = true
    M._clear()

    local crates = toml.parse_crates()

    for _,c in ipairs(crates) do
        local cached_item = M.cache[c.name]

        if cached_item then
            M.display_version(cached_item)
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

function M.setup(config)
    if config then
        config_manager.extend_with_default(config)
        M.config = config
    else
        M.config = config_manager.default()
    end
end

return M
