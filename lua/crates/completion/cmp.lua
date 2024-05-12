local completion = require("crates.completion.common")

---@class Cmp
---@field register_source fun(name: string, src: CmpCompletionSource)

---@class CmpCompletionSource
---@field registered_source boolean|nil
local M = {}

---@class LspCompletionItemKind
---@field Text integer
---@field Method integer
---@field Function integer
---@field Constructor integer
---@field Field integer
---@field Variable integer
---@field Class integer
---@field Interface integer
---@field Module integer
---@field Property integer
---@field Unit integer
---@field Value integer
---@field Enum integer
---@field Keyword integer
---@field Snippet integer
---@field Color integer
---@field File integer
---@field Reference integer
---@field Folder integer
---@field EnumMember integer
---@field Constant integer
---@field Struct integer
---@field Event integer
---@field Operator integer
---@field TypeParameter integer

---@class LspMarkupKind
---@field Plaintext string
---@field Markdown string

---@class LspMarkupContent
---@field kind string -- MarkupKind
---@field value string

---@class LspCompletionItem
---@field label string
---@field kind integer|nil -- CompletionItemKind|nil
---@field detail string|nil
---@field documentation LspMarkupContent|string|nil
---@field deprecated boolean|nil
---@field preselect boolean|nil
---@field sortText string|nil
---@field filterText string|nil
---@field insertText string|nil

---@class CmpSourceBaseApiParams
---@field option table

---@class CmpSourceCompletionApiParams
---@field context table
---@field offset number

---Source constructor.
---@return CmpCompletionSource
function M.new()
    return setmetatable({}, { __index = M })
end

---Return the source name for some information.
---@return string
function M.get_debug_name()
    return "crates"
end

---Return the source is available or not.
---@return boolean
function M:is_available()
    return vim.fn.expand("%:t") == "Cargo.toml"
end

---Return keyword pattern which will be used...
---  1. Trigger keyword completion
---  2. Detect menu start offset
---  3. Reset completion state
---@param _params CmpSourceBaseApiParams
---@return string
function M:get_keyword_pattern(_params)
    return [[\([^"'\%^<>=~,\s]\)*]]
end

---Return trigger characters.
---@param _params CmpSourceBaseApiParams
---@return string[]
function M:get_trigger_characters(_params)
    return completion.trigger_characters
end

---Invoke completion (required).
---  If you want to abort completion, just call the callback without arguments.
---@param _params CmpSourceBaseApiParams
---@param callback fun(list: CompletionList|nil)
function M:complete(_params, callback)
    completion.complete(callback)
end

function M.setup()
    if M.registered_source then
        return
    end

    ---@type Cmp
    local cmp = require("cmp")
    if not cmp then
        return
    end

    cmp.register_source("crates", M.new())
    M.registered_source = true
end

return M
