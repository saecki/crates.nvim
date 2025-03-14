local actions = require("crates.actions")
local util = require("crates.util")
local state = require("crates.state")
local completion = require("crates.completion.common")
local popup = require("crates.popup")

local M = {
    id = nil,
}

---@class ServerOpts
---@field capabilities table
---@field handlers table<string,fun(method: string, params: any, callback: function)>
---@field on_request fun(method: string, params: any)?
---@field on_notify fun(method: string, params: any)?

---@class CodeAction
---@field title string
---@field kind string
---@field action function

---@class Command
---@field title string
---@field command string
---@field arguments function[]

---@param opts ServerOpts
---@return function
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

        ---@param method string
        ---@param params any
        ---@param callback fun(method: string?, params: any)
        ---@return boolean
        ---@return integer
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

        ---@param method string
        ---@param params any
        function srv.notify(method, params)
            pcall(on_notify, method, params)
            if method == "exit" then
                dispatchers.on_exit(0, 15)
            end
        end

        ---@return boolean
        function srv.is_closing()
            return closing
        end

        function srv.terminate()
            closing = true
        end

        return srv
    end
end

-- The default Neovim reuse_client function checks root_dir,
-- which is not used or needed by our LSP client.
--
-- So just check the client name.
--
--- @param client vim.lsp.Client
--- @param config vim.lsp.ClientConfig
--- @return boolean
local function reuse_client(client, config)
    return client.name == config.name
end

function M.start_server()
    local CRATES_COMMAND = "crates_command"

    local commands = {
        ---@param cmd Command
        ---@param ctx table<string,any>
        [CRATES_COMMAND] = function(cmd, ctx)
            local action = cmd.arguments[1]
            if action then
                vim.api.nvim_buf_call(ctx.bufnr, action)
            else
                util.notify(vim.log.levels.INFO, "Action not available")
            end
        end,
    }

    local server = M.server({
        capabilities = {
            codeActionProvider = state.cfg.lsp.actions,
            completionProvider = state.cfg.lsp.completion and {
                triggerCharacters = completion.trigger_characters(),
            },
            hoverProvider = state.cfg.lsp.hover,
        },
        handlers = {
            ---@param _method string
            ---@param _params any
            ---@param callback fun(err: nil, actions: lsp.CodeAction[])
            ["textDocument/codeAction"] = function(_method, _params, callback)
                local code_actions = {}
                for _, action in ipairs(actions.get_actions()) do
                    table.insert(code_actions, {
                        title = action.name,
                        kind = "refactor.rewrite",
                        command = {
                            title = action.name,
                            command = CRATES_COMMAND,
                            arguments = { action.action },
                        },
                    })
                end
                callback(nil, code_actions)
            end,
            ---@param _method string
            ---@param _params any
            ---@param callback fun(err: nil, action: lsp.CodeAction)
            ["codeAction/resolve"] = function(_method, _params, callback)
                callback(nil, _params)
            end,
            ---@param _method string
            ---@param _params any
            ---@param callback fun(err: nil, items: CompletionList?)
            ["textDocument/completion"] = function(_method, _params, callback)
                completion.complete(function(items)
                    callback(nil, items)
                end)
            end,
            ["textDocument/hover"] = popup.show,
        },
        on_exit = function(_code, _signal, client_id)
            if M.id == client_id then
                vim.lsp.stop_client(client_id)
            end
        end,
    })

    local buf = util.current_buf()

    local client_id = vim.lsp.start({
        name = state.cfg.lsp.name,
        cmd = server,
        commands = commands,
    }, {
        bufnr = buf,
        reuse_client = reuse_client,
    })

    if client_id then
        M.id = client_id
    else
        return
    end

    local client = vim.lsp.get_client_by_id(client_id)
    if not client then
        return
    end

    state.cfg.lsp.on_attach(client, buf)
end

return M
