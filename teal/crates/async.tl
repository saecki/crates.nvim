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

return M
