local M = {Server = {}, ServerOpts = {}, CodeAction = {}, }


















local Server = M.Server
local CodeAction = M.CodeAction

local actions = require("crates.actions")
local util = require("crates.util")
local state = require("crates.state")

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
            local response, err = handler(method, params)
            callback(err, response)
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
      "update_crate",
      "upgrade_crate",
      "expand_crate_to_inline_table",
      "extract_crate_into_table",
      "remove_duplicate_section",
      "remove_original_section",
      "remove_invalid_dependency_section",
      "remove_duplicate_crate",
      "remove_original_crate",
      "rename_crate",
      "remove_duplicate_feature",
      "remove_original_feature",
      "remove_invalid_feature",
      "open_documentation",
      "open_crates.io",
      "update_all_crates",
      "upgrade_all_crates",
   }
   for _, value in ipairs(commands) do
      vim.lsp.commands[value] = function(cmd, ctx)
         local action = actions.get_actions()[cmd.command]
         if action then
            vim.api.nvim_buf_call(ctx.bufnr, action)
         else
            util.notify(vim.log.levels.INFO, "Action not available '%s'", action)
         end
      end
   end

   local server = M.server({
      capabilities = {
         codeActionProvider = true,
      },
      handlers = {

         ["textDocument/codeAction"] = function(_, _)
            local code_actions = {}
            for key, _ in pairs(actions.get_actions()) do
               table.insert(code_actions, {
                  title = util.format_title(key),
                  kind = "refactor.rewrite",
                  command = key,
               })
            end
            return code_actions
         end,
      },
   })
   local client_id = vim.lsp.start({ name = state.cfg.lsp.name, cmd = server })
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
