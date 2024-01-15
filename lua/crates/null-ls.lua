local util = require("crates.util")
local actions = require("crates.actions")

local M = {}

---@class NullLsSource
---@field name string
---@field meta NullLsMeta
---@field method NullLsMethodKind
---@field filetypes string[]
---@field generator NullLsGenerator

---@class NullLsMeta
---@field url string
---@field description string

---@class NullLsGenerator
---@field fn fun(params: NullLsParams): NullLsAction[]
---@field opts NullLsOpts

---@class NullLsOpts
---@field runtime_condition fun(params: NullLsParams)

---@class NullLsAction
---@field name string
---@field action function

---@class NullLsParams
---@field bufnr integer
---@field bufname string

---@class NullLsMethods
---@field internal NullLsInternal

---@class NullLsInternal
---@field CODE_ACTION NullLsMethodKind

---@enum NullLsMethodKind
local NullLsMethodKind = {
    CODE_ACTION = "textDocument/codeAction",
}

local ok, null_ls = pcall(require, "null-ls")
if not ok then
    util.notify(vim.log.levels.WARN, "null-ls.nvim was not found")
    return {
        setup = function(_) end
    }
end

local null_ls_methods = require("null-ls.methods")
---@type NullLsMethods
local CODE_ACTION = null_ls_methods.internal.CODE_ACTION

---@param name string
---@return NullLsSource
function M.source(name)
    return {
        name = name,
        meta = {
            url = "https://github.com/saecki/crates.nvim",
            description = "Code actions for editing `Cargo.toml` files.",
        },
        method = CODE_ACTION,
        filetypes = { "toml" },
        generator = {
            opts = {
                ---@param params NullLsParams
                ---@return boolean
                runtime_condition = function(params)
                    return params.bufname:match("Cargo%.toml$") ~= nil
                end,
            },
            ---@param params NullLsParams
            ---@return NullLsAction[]
            fn = function(params)
                ---@type NullLsAction[]
                local items = {}
                for key,action in pairs(actions.get_actions()) do
                    table.insert(items, {
                        title = util.format_title(key),
                        action = function()
                            vim.api.nvim_buf_call(params.bufnr, action)
                        end,
                    })
                end
                return items
            end,
        },
    }
end

---@params name string
function M.setup(name)
    null_ls.register(M.source(name))
end

return M
