local M = {Server = {}, ServerOpts = {}, CodeAction = {}, Command = {}, }
























local Server = M.Server
local CodeAction = M.CodeAction
local Command = M.Command

local actions = require("crates.actions")
local util = require("crates.util")
local state = require("crates.state")
local src = require("crates.src.common")

function M.server(opts)
   opts = opts or {}
   local capabilities = opts.capabilities or {}
   local on_request = opts.on_request or function(_, _) end
   local on_notify = opts.on_notify or function(_, _) end
   local handlers = opts.handlers or {}

   return function(dispatchers)
      local closing = false
      local srv = {}
      local request_id = 0

      function srv.request(method, params, callback)
         pcall(on_request, method, params)
         local handler = handlers[method]
         if handler then
            handler(method, params, callback)
         elseif method == "initialize" then
            callback(nil, {
               capabilities = capabilities,
            })
         elseif method == "shutdown" then
            callback(nil, nil)
         end
         request_id = request_id + 1
         return true, request_id
      end

      function srv.notify(method, params)
         pcall(on_notify, method, params)
         if method == "exit" then
            dispatchers.on_exit(0, 15)
         end
      end

      function srv.is_closing()
         return closing
      end

      function srv.terminate()
         closing = true
      end

      return srv
   end
end

function M.start_server()
   local commands = {
      ["crates_command"] = function(cmd, ctx)
         local action = cmd.arguments[1]
         if action then
            vim.api.nvim_buf_call(ctx.bufnr, action)
         else
            util.notify(vim.log.levels.INFO, "Action not available '%s'", action)
         end
      end,
   }

   local server = M.server({
      capabilities = {
         codeActionProvider = state.cfg.lsp.actions,
         completionProvider = state.cfg.lsp.completion and {
            triggerCharacters = src.trigger_characters,
         },
      },
      handlers = {
         ["textDocument/codeAction"] = function(_, _, callback)
            local code_actions = {}
            for key, action in pairs(actions.get_actions()) do
               local title = util.format_title(key)
               table.insert(code_actions, {
                  title = title,
                  kind = "refactor.rewrite",
                  command = {
                     title = title,
                     command = key,
                     arguments = { action },
                  },
               })
            end
            callback(nil, code_actions)
         end,
         ["textDocument/completion"] = function(_, _, callback)
            src.complete(function(items)
               callback(nil, items)
            end)
         end,
      },
   })
   local client_id = vim.lsp.start({
      name = state.cfg.lsp.name,
      cmd = server,
      commands = commands,
   })
   if not client_id then
      return
   end

   local client = vim.lsp.get_client_by_id(client_id)
   if not client then
      return
   end

   local buf = vim.api.nvim_get_current_buf()
   state.cfg.lsp.on_attach(client, buf)
end

return M
