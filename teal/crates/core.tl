local record M
    reload_crate: function(string)
    reload_deps: function(string, {Version}, Version)

    throttled_updates: {integer:{function()}}
    inner_throttled_update: function(integer|nil, boolean)
end

local api = require("crates.api")
local async = require("crates.async")
local diagnostic = require("crates.diagnostic")
local state = require("crates.state")
local toml = require("crates.toml")
local types = require("crates.types")
local Version = types.Version
local ui = require("crates.ui")
local util = require("crates.util")

M.throttled_updates = {}


M.reload_deps = async.wrap(function(crate_name: string, versions: {Version}, version: Version)
    local deps, cancelled = api.fetch_deps(crate_name, version.num)
    if cancelled then return end

    if deps then
        version.deps = deps
        for _,d in ipairs(deps) do
            -- optional dependencies are automatically promoted to features
            if d.opt and not version.features:get_feat(d.name) then
                version.features:insert({
                    name = d.name,
                    members = {},
                })
            end
        end
        version.features:sort()

        for b,cache in pairs(state.buf_cache) do
            -- update crate in all dependency sections
            for _,c in pairs(cache.crates) do
                if c:package() == crate_name then
                    local avoid_pre = not c:vers_is_pre()
                    local m, p, y = util.get_newest(versions, avoid_pre, c:vers_reqs())
                    local match = m or p or y

                    if c.vers and match == version and vim.api.nvim_buf_is_loaded(b) then
                        local diagnostics = diagnostic.process_crate_deps(c, version, deps)
                        ui.display_diagnostics(b, diagnostics)
                    end
                end
            end
        end
    end
end) as function(string, {Version}, Version)

M.reload_crate = async.wrap(function(crate_name: string)
    local crate, cancelled = api.fetch_crate(crate_name)
    local versions = crate and crate.versions
    if cancelled then return end

    if crate and versions[1] then
        state.api_cache[crate.name] = crate
    end

    for b,cache in pairs(state.buf_cache) do
        -- update crate in all dependency sections
        for k,c in pairs(cache.crates) do
            -- Don't try to fetch info from crates.io if it's a local or git crate,
            -- or from a registry other than crates.io
            -- TODO: Once there is workspace support, resolve the crate
            if c.dep_kind ~= "registry" or c.registry ~= nil then
                goto continue
            end

            if c:package() == crate_name and vim.api.nvim_buf_is_loaded(b) then
                local info, diagnostics = diagnostic.process_api_crate(c, crate)
                cache.info[k] = info
                vim.list_extend(cache.diagnostics, diagnostics)

                ui.display_crate_info(b, info, diagnostics)

                local version = info.vers_match or info.vers_upgrade
                if version then
                    M.reload_deps(c:package(), versions, version)
                end
            end

            ::continue::
        end
    end
end) as function(string)

local function update(buf: integer|nil, reload: boolean)
    buf = buf or util.current_buf()

    if reload then
        state.api_cache = {}
        api.cancel_jobs()
    end

    local sections, crates = toml.parse_crates(buf)
    local crate_cache, diagnostics = diagnostic.process_crates(sections, crates)
    local cache: state.BufCache = {
        crates = crate_cache,
        info = {},
        diagnostics = diagnostics,
    }
    state.buf_cache[buf] = cache

    ui.clear(buf)
    ui.display_diagnostics(buf, diagnostics)
    for k,c in pairs(crate_cache) do
        -- Don't try to fetch info from crates.io if it's a local or git crate,
        -- or from a registry other than crates.io
        -- TODO: Once there is workspace support, resolve the crate
        if c.dep_kind ~= "registry" or c.registry ~= nil then
            goto continue
        end

        local api_crate = state.api_cache[c:package()]
        local versions = api_crate and api_crate.versions

        if not reload and api_crate then
            local info, c_diagnostics = diagnostic.process_api_crate(c, api_crate)
            cache.info[k] = info
            vim.list_extend(cache.diagnostics, c_diagnostics)

            ui.display_crate_info(buf, info, c_diagnostics)

            local version: Version = info.vers_match or info.vers_upgrade
            if version then
                if version.deps then
                    local d_diagnostics = diagnostic.process_crate_deps(c, version, version.deps)
                    vim.list_extend(cache.diagnostics, d_diagnostics)

                    ui.display_diagnostics(buf, d_diagnostics)
                else
                    M.reload_deps(c:package(), versions, version)
                end
            end
        else
            if state.cfg.loading_indicator then
                ui.display_loading(buf, c)
            end

            M.reload_crate(c:package())
        end

        ::continue::
    end

    local callbacks = M.throttled_updates[buf]
    if callbacks then
        for _,callback in ipairs(callbacks) do
            callback()
        end
    end
    M.throttled_updates[buf] = nil
end

function M.throttled_update(buf: integer|nil, reload: boolean)
    buf = buf or util.current_buf()
    local existing = M.throttled_updates[buf]
    if not existing then
        M.throttled_updates[buf] = {}
    end

    M.inner_throttled_update(buf, reload)
end

function M.await_throttled_update_if_any(buf: integer): boolean
    local existing = M.throttled_updates[buf]
    if not existing then
        return false
    end

    coroutine.yield(function(resolve: function())
        table.insert(existing, resolve)
    end)

    return true
end

function M.hide()
    state.visible = false
    for b,_ in pairs(state.buf_cache) do
        ui.clear(b)
    end
end

function M.show()
    state.visible = true

    -- make sure we update the current buffer (first)
    local buf = util.current_buf()
    update(buf, false)

    for b,_ in pairs(state.buf_cache) do
        if b ~= buf then
            update(b, false)
        end
    end
end

function M.toggle()
    if state.visible then
        M.hide()
    else
        M.show()
    end
end

function M.update(buf: integer|nil)
    update(buf, false)
end

function M.reload(buf: integer|nil)
    update(buf, true)
end

return M
