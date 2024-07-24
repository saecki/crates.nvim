local M = {}

---@param f function
---@param ... any
function M.launch(f, ...)
    local t = coroutine.create(f)
    local function exec(...)
        local ok, data = coroutine.resume(t, ...)
        if not ok then
            error(debug.traceback(t, data))
        end
        if coroutine.status(t) ~= "dead" then
            data(exec)
        end
    end
    exec(...)
end

---@param f function
---@return function
function M.wrap(f)
    return function(...)
        M.launch(f, ...)
    end
end

---@class vim.loop.Timer
---@field start fun(self, integer, integer, function)
---@field stop fun(self)
---@field close fun(self)

---Throttle a function using tail calling
---@param f function
---@param timeout integer
---@return function
function M.throttle(f, timeout)
    local last_call = 0;

    ---@type vim.loop.Timer?
    local timer = nil

    return function(...)
        -- Make sure to stop any scheduled timers
        if timer then
            timer:stop()
        end

        ---@type integer
        local rem = timeout - (vim.loop.now() - last_call)
        -- Schedule a tail call
        if rem > 0 then
            -- Reuse timer
            if timer == nil then
                ---@type vim.loop.Timer
                timer = assert(vim.loop.new_timer())
            end

            local args = { ... }
            timer:start(rem, 0, vim.schedule_wrap(function()
                timer:stop()
                timer:close()
                timer = nil

                -- Reset here to ensure timeout between the execution of the
                -- tail call, and not the last call to throttle

                -- If it was reset in the throttle call, it could be a shorter
                -- interval between calls to f
                ---@type integer
                last_call = vim.loop.now()

                f(unpack(args))
            end))
        else
            ---@type integer
            last_call = vim.loop.now()
            f(...)
        end
    end
end

return M
