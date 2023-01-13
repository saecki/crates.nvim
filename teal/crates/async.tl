local record M end

function M.launch(f: function, ...)
    local t = coroutine.create(f)
    local function exec(...)
        local ok, data = coroutine.resume(t, ...) as (boolean, function(function))
        if not ok then
            error(debug.traceback(t as string, data as number))
        end
        if coroutine.status(t) ~= "dead" then
            data(exec)
        end
    end
    exec(...)
end

function M.wrap(f: function): function
    return function(...)
        M.launch(f, ...)
    end
end

---Throttle a function using tail calling
function M.throttle(f: function, timeout: integer): function
    local last_call = 0;

    local timer: vim.loop.Timer = nil

    return function(...)
        -- Make sure to stop any scheduled timers
        if timer then
            timer:stop()
        end

        local rem = timeout - (vim.loop.now() - last_call)
        -- Schedule a tail call
        if rem > 0 then
            -- Reuse timer
            if timer is nil then
                timer = vim.loop.new_timer()
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
                last_call = vim.loop.now()

                f(unpack(args))
            end))
        else
            last_call = vim.loop.now()
            f(...)
        end
    end
end

return M
