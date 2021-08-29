local M = {}

local cmp = require('cmp')
local core = require('crates.core')
local util = require('crates.util')

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

---Invoke completion (required).
---  If you want to abort completion, just call the callback without arguments.
---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
function M.complete(_, _, callback)
    local linenr = vim.api.nvim_win_get_cursor(0)[1]
    local crates = util.get_lines_crates({ s = linenr - 1, e = linenr })
    if not crates or not crates[1] then
        return
    end
    local versions = crates[1].versions

    local results = {}
    for _,v in ipairs(versions) do
        local r = {
            label = v.num,
            kind = cmp.lsp.CompletionItemKind.Value,
        }
        if v.yanked then
            r.deprecated = true
            r.documentation = core.cfg.popup.text.yanked
        end
        table.insert(results, r)
    end

    callback(results)
end

return M
