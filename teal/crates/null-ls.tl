local record M end

local util = require("crates.util")
local actions = require("crates.actions")

local ok, null_ls = pcall(require, "null-ls")
if not ok then
    util.notify(vim.log.levels.WARN, "null-ls.nvim was not found")
    return {
        setup = function(_: string) end
    }
end
local null_ls_methods = require("null-ls.methods")
local CODE_ACTION = null_ls_methods.internal.CODE_ACTION

function M.source(name: string): null_ls.Source
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
                runtime_condition = function(params: null_ls.Params): boolean
                    return params.bufname:match("Cargo%.toml$") ~= nil
                end,
            },
            fn = function(params: null_ls.Params): {null_ls.Action}
                local items: {null_ls.Action} = {}
                for title,action in pairs(actions.get_actions()) do
                    table.insert(items, {
                        title = title,
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

function M.setup(name: string)
    null_ls.register(M.source(name))
end

return M
