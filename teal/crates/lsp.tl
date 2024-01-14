local record M
    record Server

    end

    record ServerOpts
        handlers: {string:function(method: string, params: any): any}
        on_request: function(method: string, params: any)
        on_notify: function(method: string, params: any)
        capabilities: table
    end

    record CodeAction
        title: string
        kind: string
        action: function
    end

    record Command
        title: string
        command: string
        arguments: {function}
    end
end

local Server = M.Server
local CodeAction = M.CodeAction
local Command = M.Command

local actions = require("crates.actions")
local util = require("crates.util")
local state = require("crates.state")

function M.server(opts: {string:any}): function(any)
	opts = opts or {}
	local capabilities = opts.capabilities or {}
	local on_request = opts.on_request as function or function(_, _) end
	local on_notify = opts.on_notify as function or function(_, _) end
	local handlers: {string:function} = opts.handlers as {string:function} or {}

	return function(dispatchers: {string:function}): Server
		local closing = false
		local srv = {}
		local request_id = 0

		function srv.request(method: string, params: any, callback: function): boolean, integer
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

		function srv.notify(method: string, params: any)
			pcall(on_notify, method, params)
			if method == "exit" then
				dispatchers.on_exit(0, 15)
			end
		end

		function srv.is_closing(): boolean
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
        ["crates_command"] = function(cmd: Command, ctx: {string:any})
            local action = cmd.arguments[1]
            if action then
                vim.api.nvim_buf_call(ctx.bufnr as integer, action)
            else
                util.notify(vim.log.levels.INFO, "Action not available '%s'", action)
            end
        end
    }

	local server = M.server({
		capabilities = {
			codeActionProvider = true,
		},
		handlers = {
			---@param params lsp.CodeActionParams
			["textDocument/codeAction"] = function(_, _): {CodeAction}
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
				return code_actions
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

    local buf = vim.api.nvim_get_current_buf() as integer
    state.cfg.lsp.on_attach(client, buf)
end

return M
