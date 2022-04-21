local M = {}

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

function M.wrap(f)
   return function(...)
      M.launch(f, ...)
   end
end

return M
