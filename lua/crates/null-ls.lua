local M = {}

local util = require("crates.util")
local actions = require("crates.actions")

local ok, null_ls = pcall(require, "null-ls")
if not ok then
   util.notify(vim.log.levels.WARN, "null-ls.nvim was not found")
   return {
      setup = function(_) end,
   }
end
local null_ls_methods = require("null-ls.methods")
local CODE_ACTION = null_ls_methods.internal.CODE_ACTION

local function format_title(name)
   return name:sub(1, 1):upper() .. name:gsub("_", " "):sub(2)
end

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
            runtime_condition = function(params)
               return params.bufname:match("Cargo%.toml$") ~= nil
            end,
         },
         fn = function(params)
            local items = {}
            for key, action in pairs(actions.get_actions()) do
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

function M.setup(name)
   null_ls.register(M.source(name))
end

return M
