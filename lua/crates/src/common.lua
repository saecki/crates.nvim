local api = require("crates.api")
local async = require("crates.async")
local core = require("crates.core")
local state = require("crates.state")
local types = require("crates.types")
local Span = types.Span
local util = require("crates.util")

---@class CompletionSource
---@field trigger_characters string[]
local M = {
    trigger_characters = {
        '"', "'", ".", "<", ">", "=", "^", "~",
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
    },
}

---@class CompletionList
---@field isIncomplete boolean
---@field items CompletionItem[]

---@class CompletionItem
---@field label string
---@field kind integer|nil -- CompletionItemKind|nil
---@field detail string|nil
---@field documentation string|nil
---@field deprecated boolean|nil
---@field sortText string|nil
---@field insertText string|nil
---@field cmp CmpCompletionExtension|nil

---@class CmpCompletionExtension
---@field kind_text string
---@field kind_hl_group string

-- lsp CompletionItemKind.Value
local VALUE_KIND = 12

---@param crate TomlCrate
---@param versions ApiVersion[]
---@return CompletionList
local function complete_versions(crate, versions)
    local items = {}

    for i, v in ipairs(versions) do
        ---@type CompletionItem
        local r = {
            label = v.num,
            kind = VALUE_KIND,
            sortText = string.format("%04d", i),
        }
        if state.cfg.src.insert_closing_quote then
            if crate.vers and not crate.vers.quote.e then
                r.insertText = v.num .. crate.vers.quote.s
            end
        end
        if v.yanked then
            r.deprecated = true
            r.documentation = state.cfg.src.text.yanked
        elseif v.parsed.pre then
            r.documentation = state.cfg.src.text.prerelease
        end
        if state.cfg.src.cmp.use_custom_kind then
            r.cmp = {
                kind_text = state.cfg.src.cmp.kind_text.version,
                kind_hl_group = state.cfg.src.cmp.kind_highlight.version,
            }
        end

        table.insert(items, r)
    end

    return {
        isIncomplete = false,
        items = items,
    }
end

---@param crate TomlCrate
---@param cf TomlFeature
---@param versions ApiVersion[]
---@return CompletionList
local function complete_features(crate, cf, versions)
    local newest = util.get_newest(versions, crate:vers_reqs())

    if not newest then
        return {
            isIncomplete = false,
            items = {},
        }
    end

    local items = {}
    for _, f in ipairs(newest.features.list) do
        if f.name == "default" or crate:get_feat(f.name) then
            goto continue
        end

        ---@type CompletionItem
        local r = {
            label = f.name,
            kind = VALUE_KIND,
            sortText = f.name,
            documentation = table.concat(f.members, "\n"),
        }
        if state.cfg.src.insert_closing_quote then
            if not cf.quote.e then
                r.insertText = f.name .. cf.quote.s
            end
        end
        if state.cfg.src.cmp.use_custom_kind then
            r.cmp = {
                kind_text = state.cfg.src.cmp.kind_text.feature,
                kind_hl_group = state.cfg.src.cmp.kind_highlight.feature,
            }
        end

        table.insert(items, r)

        ::continue::
    end

    return {
        isIncomplete = not newest.deps,
        items = items,
    }
end

---@return CompletionList|nil
local function complete()
    local buf = util.current_buf()

    local awaited = core.await_throttled_update_if_any(buf)
    if awaited and buf ~= util.current_buf() then
        return
    end

    local line, col = util.cursor_pos()
    local crates = util.get_line_crates(buf, Span.new(line, line + 1))
    local _, crate = next(crates)
    if not crate then
        return
    end

    local api_crate = state.api_cache[crate:package()]

    if not api_crate and api.is_fetching_crate(crate:package()) then
        local _api_crate, cancelled = api.await_crate(crate:package())

        if cancelled or buf ~= util.current_buf() then
            return
        end

        line, col = util.cursor_pos()
        crates = util.get_line_crates(buf, Span.new(line, line + 1))
        _, crate = next(crates)
        if not crate then
            return
        end

        api_crate = state.api_cache[crate:package()]
    end

    if not api_crate then
        return
    end

    if crate.vers and crate.vers.line == line and crate.vers.col:moved(0, 1):contains(col) then
        return complete_versions(crate, api_crate.versions)
    elseif crate.feat and crate.feat.line == line and crate.feat.col:moved(0, 1):contains(col) then
        for _, f in ipairs(crate.feat.items) do
            if f.col:moved(0, 1):contains(col - crate.feat.col.s) then
                return complete_features(crate, f, api_crate.versions)
            end
        end
    end
end

---@param callback fun(list: CompletionList|nil)
function M.complete(callback)
    vim.schedule(async.wrap(function()
        callback(complete())
    end))
end

return M
