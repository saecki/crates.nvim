local M = {}

local cmp = require('cmp')
local core = require('crates.core')
local util = require('crates.util')
local Range = require('crates.types').Range

---Source constructor.
M.new = function()
    return setmetatable({}, { __index = M })
end

---Return the source name for some information.
M.get_debug_name = function()
    return 'crates'
end

---Return the source is available or not.
---@return boolean
function M.is_available(_)
    return vim.fn.expand("%:t") == "Cargo.toml"
end

---Return keyword pattern which will be used...
---  1. Trigger keyword completion
---  2. Detect menu start offset
---  3. Reset completion state
---@param params cmp.SourceBaseApiParams
---@return string
function M.get_keyword_pattern(_, _)
    return [[\([^"'\%^<>=~,\s]\)*]]
end

---Return trigger characters.
---@param params cmp.SourceBaseApiParams
---@return string[]
function M.get_trigger_characters(_, _)
    return { '"', "'", ".", "<", ">", "=", "^", "~", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
end

---@param versions Version[]
local function complete_versions(versions)
    local results = {}

    for i,v in ipairs(versions) do
        local r = {
            label = v.num,
            kind = cmp.lsp.CompletionItemKind.Value,
            sortText = string.format("%04d", i),
        }
        if v.yanked then
            r.deprecated = true
            r.documentation = core.cfg.cmp.text.yanked
        elseif v.parsed.suffix then
            r.documentation = core.cfg.cmp.text.prerelease
        end

        table.insert(results, r)
    end

    return results
end

---@param crate Crate
---@param versions Version[]
local function complete_features(crate, versions)
    local results = {}

    local avoid_pre = core.cfg.avoid_prerelease and not crate.req_has_suffix
    local newest = util.get_newest(versions, avoid_pre, crate.reqs)

    for _,f in pairs(newest.features) do
        local contains_feature = false
        for _,cf in pairs(crate.feats) do
            if cf.name == f.name then
                contains_feature = true
                break
            end
        end
        if not contains_feature then
            local r = {
                label = f.name,
                kind = cmp.lsp.CompletionItemKind.Value,
                sortText = f.name,
            }

            table.insert(results, r)
        end
    end

    return results
end

---Invoke completion (required).
---  If you want to abort completion, just call the callback without arguments.
---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
function M.complete(_, _, callback)
    local pos = vim.api.nvim_win_get_cursor(0)
    local line = pos[1] - 1
    local col = pos[2]

    local crates = util.get_lines_crates(Range.new(line, line + 1))
    if not crates or not crates[1] or not crates[1].versions then
        callback(nil)
        return
    end

    local crate = crates[1].crate
    local versions = crates[1].versions

    if crate.reqs and crate.req_line == line and crate.req_col:moved(0, 1):contains(col) then
        callback(complete_versions(versions))
    elseif crate.feats and crate.feat_line == line and crate.feat_col:moved(0, 1):contains(col) then
        for _,f in pairs(crate.feats) do
            if f.col:moved(0, 1):contains(col - crate.feat_col.s) then
                callback(complete_features(crate, versions))
                return
            end
        end

        callback(nil)
    else
        callback(nil)
    end
end

return M
