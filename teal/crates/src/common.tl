local record M
    record CompletionList
        isIncomplete: boolean
        items: {CompletionItem}
    end

    record CompletionItem
        label: string
        kind: integer|nil -- CompletionItemKind|nil
        detail: string|nil
        documentation: string|nil
        deprecated: boolean|nil
        sortText: string|nil
        insertText: string|nil
        cmp: CmpCompletionExtension|nil
    end

    record CmpCompletionExtension
        kind_text: string
        kind_hl_group: string
    end
end

local CompletionItem = M.CompletionItem
local CompletionList = M.CompletionList

local api = require("crates.api")
local async = require("crates.async")
local core = require("crates.core")
local state = require("crates.state")
local toml = require("crates.toml")
local types = require("crates.types")
local Range = types.Range
local Version = types.Version
local util = require("crates.util")

local VALUE_KIND = 12

local function complete_versions(crate: toml.Crate, versions: {Version}): CompletionList
    local items = {}

    for i,v in ipairs(versions) do
        local r: CompletionItem = {
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

local function complete_features(crate: toml.Crate, cf: toml.Feature, versions: {Version}): CompletionList
    local avoid_pre = not crate:vers_is_pre()
    local newest = util.get_newest(versions, avoid_pre, crate:vers_reqs())

    if not newest then
        return {
            isIncomplete = false,
            items = {},
        }
    end

    local items = {}
    for _,f in ipairs(newest.features.list) do
        local crate_feat = crate:get_feat(f.name)
        if not crate_feat then
            local r: CompletionItem = {
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
        end
    end

    return {
        isIncomplete = not newest.deps,
        items = items,
    }
end

local function complete(): CompletionList|nil
    local buf = util.current_buf()

    local awaited = core.await_throttled_update_if_any(buf)
    if awaited and buf ~= util.current_buf() then
        return
    end

    local line, col = util.cursor_pos()
    local crates = util.get_line_crates(buf, Range.new(line, line + 1))
    local _,crate = next(crates)
    if not crate then
        return
    end

    local api_crate = state.api_cache[crate:package()]

    if not api_crate and api.is_fetching_crate(crate:package()) then
        local _api_crate,cancelled = api.await_crate(crate:package())

        if cancelled or buf ~= util.current_buf() then
            return
        end

        line, col = util.cursor_pos()
        crates = util.get_line_crates(buf, Range.new(line, line + 1))
        _,crate = next(crates)
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
        for _,f in ipairs(crate.feat.items) do
            if f.col:moved(0, 1):contains(col - crate.feat.col.s) then
                return complete_features(crate, f, api_crate.versions)
            end
        end
    end
end

function M.complete(callback: function(CompletionList|nil))
    vim.schedule(async.wrap(function()
        callback(complete())
    end))
end

return M
