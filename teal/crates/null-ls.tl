local record M end

local actions = require("crates.actions")
local ok, null_ls = pcall(require, "null-ls")
if not ok then
    vim.notify("null-ls.nvim was not found", vim.log.levels.WARN, { title = "crates.nvim" })
    return {
        setup = function(_: string) end
    }
end
local null_ls_methods = require("null-ls.methods")
local CODE_ACTION = null_ls_methods.internal.CODE_ACTION

local function format_title(name: string): string
    return name:sub(1, 1):upper() .. name:gsub("_", " "):sub(2)
end

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
                for key,action in pairs(actions.get_actions()) do
                    table.insert(items, {
                        title = format_title(key),
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
