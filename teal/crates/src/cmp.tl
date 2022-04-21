local record M end

local cmp = require("cmp")
local lsp = cmp.lsp
local src = require("crates.src.common")

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
function M:get_keyword_pattern(_: cmp.SourceBaseApiParams): string
    return [[\([^"'\%^<>=~,\s]\)*]]
end

---Return trigger characters.
function M:get_trigger_characters(_: cmp.SourceBaseApiParams): {string}
    return { '"', "'", ".", "<", ">", "=", "^", "~", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
end

---Invoke completion (required).
---  If you want to abort completion, just call the callback without arguments.
function M:complete(_: cmp.SourceCompletionApiParams, callback: function(lsp.CompletionList|nil))
    src.complete(callback as function(src.CompletionList|nil))
end

return M
