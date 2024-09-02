local api = require("crates.api")
local async = require("crates.async")
local diagnostic = require("crates.diagnostic")
local state = require("crates.state")
local toml = require("crates.toml")
local DepKind = toml.DepKind
local ui = require("crates.ui")
local util = require("crates.util")

---@class Core
---@field throttled_updates table<integer,fun()[]>
---@field inner_throttled_update fun(buf: integer?, reload: boolean?)
local M = {
    throttled_updates = {},
}

---@type fun(crate_name: string)
M.load_crate = async.wrap(function(crate_name)
    local crate, cancelled = api.fetch_crate(crate_name)
    local versions = crate and crate.versions
    if cancelled then
        return
    end

    ---@cast versions -nil
    if crate and next(versions) then
        state.api_cache[crate.name] = crate
    end

    for buf, cache in pairs(state.buf_cache) do
        -- update crate in all dependency sections
        for k, c in pairs(cache.crates) do
            -- Don't try to fetch info from crates.io if it's a local or git crate,
            -- or from a registry other than crates.io
            -- TODO: Once there is workspace support, resolve the crate
            if c.dep_kind ~= DepKind.REGISTRY or c.registry ~= nil then
                goto continue
            end

            if c:package() == crate_name and vim.api.nvim_buf_is_loaded(buf) then
                local c_diagnostics = {}
                local info = diagnostic.process_api_crate(c, crate, c_diagnostics)
                cache.info[k] = info
                vim.list_extend(cache.diagnostics, c_diagnostics)

                ui.display_crate_info(buf, { info })
                ui.display_diagnostics(buf, {}, c_diagnostics)
            end

            ::continue::
        end
    end
end)

---@param buf integer?
---@param reload boolean?
local function update(buf, reload)
    buf = buf or util.current_buf()

    if reload then
        state.api_cache = {}
        api.cancel_jobs()
    end

    local sections, crates, working_crates = toml.parse_crates(buf)
    local crate_cache, diagnostics = diagnostic.process_crates(sections, crates)
    ---@type BufCache
    local cache = {
        crates = crate_cache,
        info = {},
        diagnostics = diagnostics,
        working_crates = working_crates,
    }
    state.buf_cache[buf] = cache

    local crates_info = {}
    local crates_loading = {}
    local custom_diagnostics = {}
    for k, c in pairs(crate_cache) do
        -- Don't try to fetch info from crates.io if it's a local or git crate,
        -- or from a registry other than crates.io
        -- TODO: Once there is workspace support, resolve the crate
        if c.dep_kind ~= DepKind.REGISTRY or c.registry ~= nil then
            goto continue
        end

        local api_crate = state.api_cache[c:package()]
        if not reload and api_crate then
            local info = diagnostic.process_api_crate(c, api_crate, custom_diagnostics)
            cache.info[k] = info

            table.insert(crates_info, info)
        else
            if state.cfg.loading_indicator then
                table.insert(crates_loading, c)
            end

            M.load_crate(c:package())
        end

        ::continue::
    end

    ui.clear(buf)
    ui.display_crate_info(buf, crates_info)
    ui.display_loading(buf, crates_loading)
    ui.display_diagnostics(buf, diagnostics, custom_diagnostics)

    vim.list_extend(cache.diagnostics, custom_diagnostics)

    local callbacks = M.throttled_updates[buf]
    if callbacks then
        for _, callback in ipairs(callbacks) do
            callback()
        end
    end
    M.throttled_updates[buf] = nil
end

---@param buf integer?
---@param reload boolean?
function M.throttled_update(buf, reload)
    buf = buf or util.current_buf()
    local existing = M.throttled_updates[buf]
    if not existing then
        M.throttled_updates[buf] = {}
    end

    M.inner_throttled_update(buf, reload)
end

---@param buf integer
---@return boolean
function M.await_throttled_update_if_any(buf)
    local existing = M.throttled_updates[buf]
    if not existing then
        return false
    end

    ---@param resolve fun()
    coroutine.yield(function(resolve)
        table.insert(existing, resolve)
    end)

    return true
end

function M.hide()
    state.visible = false
    for b, _ in pairs(state.buf_cache) do
        ui.clear(b)
    end
end

function M.show()
    state.visible = true

    -- make sure we update the current buffer (first)
    local buf = util.current_buf()
    update(buf, false)

    for b, _ in pairs(state.buf_cache) do
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

---@param buf integer?
function M.update(buf)
    update(buf, false)
end

---@param buf integer?
function M.reload(buf)
    update(buf, true)
end

return M
