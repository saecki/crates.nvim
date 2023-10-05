local record M
    registered_source: boolean

    record lsp
        record CompletionItemKind
            Text: integer
            Method: integer
            Function: integer
            Constructor: integer
            Field: integer
            Variable: integer
            Class: integer
            Interface: integer
            Module: integer
            Property: integer
            Unit: integer
            Value: integer
            Enum: integer
            Keyword: integer
            Snippet: integer
            Color: integer
            File: integer
            Reference: integer
            Folder: integer
            EnumMember: integer
            Constant: integer
            Struct: integer
            Event: integer
            Operator: integer
            TypeParameter: integer
        end

        record MarkupKind
            Plaintext: string
            Markdown: string
        end

        record MarkupContent
            kind: string -- MarkupKind
            value: string
        end

        record CompletionItem
            label: string
            kind: integer|nil -- CompletionItemKind|nil
            detail: string|nil
            documentation: MarkupContent|string|nil
            deprecated: boolean|nil
            preselect: boolean|nil
            sortText: string|nil
            filterText: string|nil
            insertText: string|nil
        end

        record CompletionList
            isIncomplete: boolean
            items: {CompletionItem}
        end
    end

    record cmp
        lsp: lsp

        register_source: function(string, {string:any})

        record SourceBaseApiParams
            option: table
        end

        record SourceCompletionApiParams
            context: table
            offset: number
        end
    end
end

local src = require("crates.src.common")
local util = require("crates.util")

---Source constructor.
function M.new(): M
    return setmetatable({}, { __index = M })
end

---Return the source name for some information.
function M.get_debug_name(): string
    return "crates"
end

---Return the source is available or not.
function M:is_available(): boolean
    return vim.fn.expand("%:t") == "Cargo.toml"
end

---Return keyword pattern which will be used...
---  1. Trigger keyword completion
---  2. Detect menu start offset
---  3. Reset completion state
function M:get_keyword_pattern(_: M.cmp.SourceBaseApiParams): string
    return [[\([^"'\%^<>=~,\s]\)*]]
end

---Return trigger characters.
function M:get_trigger_characters(_: M.cmp.SourceBaseApiParams): {string}
    return { '"', "'", ".", "<", ">", "=", "^", "~", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
end

---Invoke completion (required).
---  If you want to abort completion, just call the callback without arguments.
function M:complete(_: M.cmp.SourceCompletionApiParams, callback: function(M.lsp.CompletionList|nil))
    src.complete(callback as function(src.CompletionList|nil))
end

function M.setup()
    if M.registered_source then
        return
    end

    local cmp = package.loaded["cmp"] as M.cmp
    if not cmp then
        return
    end

    cmp.register_source("crates", M.new())
    M.registered_source = true
end

return M
