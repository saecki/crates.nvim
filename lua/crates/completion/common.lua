local api = require("crates.api")
local async = require("crates.async")
local core = require("crates.core")
local edit = require("crates.edit")
local semver = require("crates.semver")
local state = require("crates.state")
local toml = require("crates.toml")
local TomlCrateSyntax = toml.TomlCrateSyntax
local types = require("crates.types")
local Span = types.Span
local ui = require("crates.ui")
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
---@field deprecated boolean|nil
---@field sortText string|nil
---@field insertText string|nil
---@field cmp CmpCompletionExtension|nil

---@class CmpCompletionExtension
---@field kind_text string
---@field kind_hl_group string

-- lsp spec: https://microsoft.github.io/language-server-protocol/specifications/specification-current
local CompletionItemKind = {
    VALUE = 12,
}
local InsertTextFormat = {
    PLAIN_TEXT = 1,
    SNIPPET = 2,
}

---@param crate TomlCrate
---@param versions ApiVersion[]
---@return CompletionList
local function complete_versions(crate, versions)
    local items = {}

    for i, v in ipairs(versions) do
        ---@type CompletionItem
        local r = {
            label = v.num,
            kind = CompletionItemKind.VALUE,
            sortText = string.format("%04d", i),
        }
        if state.cfg.completion.insert_closing_quote then
            if crate.vers and not crate.vers.quote.e then
                r.insertText = v.num .. crate.vers.quote.s
            end
        end
        local detail = { v.created:display(state.cfg.date_format) }
        if v.yanked then
            r.deprecated = true
            table.insert(detail, state.cfg.completion.text.yanked)
        elseif v.parsed.pre then
            table.insert(detail, state.cfg.completion.text.prerelease)
        end
        r.detail = table.concat(detail, "\n")
        if state.cfg.completion.cmp.use_custom_kind then
            r.cmp = {
                kind_text = state.cfg.completion.cmp.kind_text.version,
                kind_hl_group = state.cfg.completion.cmp.kind_highlight.version,
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

        -- handle `dep:<crate_name>` features
        local insert_text = nil
        if f.dep then
            local parent_name = string.sub(f.name, 5)
            -- don't suggest duplicates         or already enabled features
            if newest.features.map[parent_name] or crate:get_feat(parent_name) then
                goto continue
            end

            insert_text = parent_name
        end

        ---@type CompletionItem
        local r = {
            label = f.name,
            kind = CompletionItemKind.VALUE,
            sortText = f.name,
            detail = table.concat(f.members, "\n"),
            insertText = insert_text,
        }
        if state.cfg.completion.insert_closing_quote then
            if not cf.quote.e then
                r.insertText = (insert_text or f.name) .. cf.quote.s
            end
        end
        if state.cfg.completion.cmp.use_custom_kind then
            r.cmp = {
                kind_text = state.cfg.completion.cmp.kind_text.feature,
                kind_hl_group = state.cfg.completion.cmp.kind_highlight.feature,
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

---@param buf integer
---@param prefix string
---@param line integer
---@param col Span
---@param crate TomlCrate?
---@return CompletionList?
local function complete_crates(buf, prefix, line, col, crate)
    if #prefix < state.cfg.completion.crates.min_chars then
        return
    end

    ---@type string[]
    local search = state.search_cache.searches[prefix]
    if not search then
        ---@type number?
        local transaction
        if state.cfg.search_indicator then
            transaction = ui.show_search_indicator(buf, line)
        end

        ---@type ApiCrateSummary[]?, boolean?
        local searches, cancelled
        if api.is_fetching_search(prefix) then
            searches, cancelled = api.await_search(prefix)
        else
            api.cancel_search_jobs()
            searches, cancelled = api.fetch_search(prefix)
        end
        if cancelled then
            return
        end

        if searches then
            state.search_cache.searches[prefix] = {}
            for _, result in ipairs(searches) do
                state.search_cache.results[result.name] = result
                table.insert(state.search_cache.searches[prefix], result.name)
            end
        end
        search = state.search_cache.searches[prefix]

        if transaction then
            local cancelled = ui.hide_search_indicator(buf, transaction)
            if cancelled then
                return
            end
        end

        if not search then
            return
        end
    end

    local itemDefaults = {
        insertTextFormat = InsertTextFormat.PLAIN_TEXT,
        editRange = nil,
    }
    local function insertText(name) return name end
    local function additionalTextEdits(_version) end

    if crate then
        if crate.vers then
            additionalTextEdits = function(version)
                local parsed = semver.parse_version(version)
                local text = edit.version_text(crate, parsed)
                return { {
                    range = crate.vers.col:range(crate.vers.line),
                    newText = text,
                } }
            end
        else
            if crate.syntax == TomlCrateSyntax.TABLE then
                itemDefaults.insertTextFormat = InsertTextFormat.SNIPPET
                itemDefaults.editRange = Span.new(col.s, crate.section.header_col.e):range(line)
                insertText = function(name, version)
                    return ('%s]\nversion = "${1:%s}"'):format(name, version)
                end
            elseif crate.syntax == TomlCrateSyntax.INLINE_TABLE then
                local vers_col = edit.col_to_insert(crate, "vers")
                additionalTextEdits = function(version)
                    return { {
                        range = Span.new(vers_col, vers_col):range(line),
                        newText = string.format(' version = "%s",', version),
                    } }
                end
            else -- crate.syntax == TomlCrateSyntax.PLAIN
                error("unreachable")
            end
        end
    else
        itemDefaults.insertTextFormat = InsertTextFormat.SNIPPET
        itemDefaults.editRange = col:range(line)
        insertText = function(name, version)
            return ('%s = "${1:%s}"'):format(name, version)
        end
    end

    local results = {}
    for _, r in ipairs(search) do
        local result = state.search_cache.results[r]
        table.insert(results, {
            label = result.name,
            kind = CompletionItemKind.VALUE,
            detail = table.concat({ result.newest_version, result.description }, "\n"),
            textEditText = insertText(result.name, result.newest_version),
            additionalTextEdits = additionalTextEdits(result.newest_version),
        })
    end

    return {
        isIncomplete = false,
        items = results,
        itemDefaults = itemDefaults,
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

    if state.cfg.completion.crates.enabled then
        local working_crates = state.buf_cache[buf].working_crates
        for _, wcrate in ipairs(working_crates) do
            if wcrate and wcrate.col:moved(0, 1):contains(col) and line == wcrate.line then
                local prefix = wcrate.name:sub(1, col - wcrate.col.s)
                return complete_crates(buf, prefix, wcrate.line, wcrate.col, nil);
            end
        end
    end

    if not crate then
        return
    end

    if state.cfg.completion.crates.enabled then
        local pkg_line, pkg_col = crate:package_pos()
        if pkg_line == line and pkg_col:moved(0, 1):contains(col) then
            local prefix = crate:package():sub(1, col - pkg_col.s)
            return complete_crates(buf, prefix, line, pkg_col, crate);
        end
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
