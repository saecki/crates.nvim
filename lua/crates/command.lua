local M = {}

local actions = require("crates.actions")

local sub_commands = {
   { "upgrade", actions.upgrade_crate },
   { "upgrade_selected", actions.upgrade_crates },
   { "upgrade_all", actions.upgrade_all_crates },
   { "update", actions.update_crate },
   { "update_selected", actions.update_crates },
   { "update_all", actions.update_all_crates },

   { "expand_to_inline_table", actions.expand_plain_crate_to_inline_table },
   { "extract_into_table", actions.extract_crate_into_table },

   { "open_homepage", actions.open_homepage },
   { "open_repository", actions.open_repository },
   { "open_documentation", actions.open_documentation },
   { "open_cratesio", actions.open_crates_io },
}

local function complete(arglead, line)
   local matches = {}

   local words = vim.split(line, "%s+")
   if #words > 2 then
      return matches
   end

   for _, s in ipairs(sub_commands) do
      if vim.startswith(s[1], arglead) then
         table.insert(matches, s[1])
      end
   end
   return matches
end

local function exec(cmd)
   for _, s in ipairs(sub_commands) do
      if s[1] == cmd.args then
         s[2]()
         return
      end
   end

   print(string.format("unknown sub command \"%s\"", cmd.args))
end

function M.register()
   vim.api.nvim_create_user_command("Crates", exec, {
      nargs = 1,
      range = true,
      complete = complete,
   })
end

return M
