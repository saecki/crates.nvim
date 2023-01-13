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


function M.throttle(f, timeout)
   local last_call = 0;

   local timer = nil

   return function(...)

      if timer then
         timer:stop()
      end

      local rem = timeout - (vim.loop.now() - last_call)

      if rem > 0 then

         if type(timer) == "nil" then
            timer = vim.loop.new_timer()
         end

         local args = { ... }
         timer:start(rem, 0, vim.schedule_wrap(function()
            timer:stop()
            timer:close()
            timer = nil






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
