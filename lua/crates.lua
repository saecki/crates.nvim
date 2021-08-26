local M = {}

local job = require("plenary.job")
local toml = require("crates.toml")
local semver = require("crates.semver")
local config_manager = require("crates.config")

local api = "https://crates.io/api/v1"

M.vers_cache = {}
M.crate_cache = {}
M.running_jobs = {}
M.visible = false

function M.get_filepath()
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

function M.get_newest(crate, versions, avoid_pre)
    if not versions then
        return nil
    end
    
    local newest_yanked = nil
    local newest_pre = nil

    for _,v in ipairs(versions) do
        if not v.yanked then
            if avoid_pre then
                if v.parsed.suffix then
                    newest_pre = newest_pre or v
                else
                    return v
                end
            else
                return v
            end
        else
            newest_yanked = newest_yanked or v
        end
    end

    return newest_pre or newest_yanked
end

function M.display_versions(crate, versions)
    if not M.visible then
        return
    end

    local avoid_pre = M.config.avoid_prerelease and not crate.req_has_suffix
    local newest = M.get_newest(crate, versions, avoid_pre)

    local virt_text
    if newest then
        if semver.matches_requirements(newest.parsed, crate.reqs) then
            -- version matches, no upgrade available
            virt_text = { { string.format(M.config.text.version, newest.num), M.config.highlight.version } }
        else
            -- version does not match, upgrade available
            local match_yanked = nil
            local match_pre = nil
            local match = nil
            for _,v in ipairs(versions) do
                if semver.matches_requirements(v.parsed, crate.reqs) then
                    if not v.yanked then
                        if avoid_pre then
                            if v.parsed.suffix then
                                match_pre = match_pre or v
                            else
                                match = v
                                break
                            end
                        else
                            match = v
                            break
                        end
                    else
                        match_yanked = match_yanked or v
                    end
                end
            end

            if match then
                -- found a match
                virt_text = {
                    { string.format(M.config.text.version, match.num), M.config.highlight.version },
                    { string.format(M.config.text.update, newest.num), M.config.highlight.update },
                }
            elseif match_pre then
                -- found a pre-release match
                virt_text = {
                    { string.format(M.config.text.prerelease, match_pre.num), M.config.highlight.prerelease },
                    { string.format(M.config.text.update, newest.num), M.config.highlight.update },
                }
            elseif match_yanked then
                -- found a yanked match
                virt_text = {
                    { string.format(M.config.text.yanked, match_yanked.num), M.config.highlight.yanked },
                    { string.format(M.config.text.update, newest.num), M.config.highlight.update },
                }
            else
                -- no match found
                virt_text = {
                    { M.config.text.nomatch, M.config.highlight.nomatch },
                    { string.format(M.config.text.update, newest.num), M.config.highlight.update },
                }
            end
        end
    else
        virt_text = { { M.config.text.error, M.config.highlight.error } }
    end

    vim.api.nvim_buf_clear_namespace(0, M.namespace_id, crate.linenr - 1, crate.linenr)
    vim.api.nvim_buf_set_virtual_text(0, M.namespace_id, crate.linenr - 1, virt_text, {})
end

function M.display_loading(crate)
    local virt_text = { { M.config.text.loading, M.config.highlight.loading } }
    vim.api.nvim_buf_clear_namespace(0, M.namespace_id, crate.linenr - 1, crate.linenr)
    vim.api.nvim_buf_set_virtual_text(0, M.namespace_id, crate.linenr - 1, virt_text, {})
end

function M.reload_crate(crate)
    local function on_fetched(resp)
        local data = vim.fn.json_decode(resp)

        local versions = {}
        if data and type(data) ~= "userdata" and data.versions then
            for _,v in ipairs(data.versions) do
                if v.num then
                    local version = {
                        num = v.num,
                        yanked = v.yanked,
                        parsed = semver.parse_version(v.num),
                    }
                    table.insert(versions, version)
                end
            end
        end

        if versions and versions[1] then
            M.vers_cache[crate.name] = versions
        end

        M.display_versions(crate, versions)
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

function M.hide()
    M.visible = false
    M._clear()
end

function M.reload()
    M.visible = true
    M.vers_cache = {}
    M._clear()

    local filepath = M.get_filepath()
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

    local filepath = M.get_filepath()
    local crates = toml.parse_crates()

    M.crate_cache[filepath] = {}

    for _,c in ipairs(crates) do
        local versions = M.vers_cache[c.name]

        M.crate_cache[filepath][c.name] = c

        if versions then
            M.display_versions(c, versions)
        else
            M.reload_crate(c)
        end
    end
end

function M.toggle()
    if M.visible then
        M.hide()
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
