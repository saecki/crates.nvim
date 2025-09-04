local M = {}

---@type {[1]: string, [2]: function}[]
local sub_commands = {
    { "hide",                               function() return require("crates.core").hide() end },
    { "show",                               function() return require("crates.core").show() end },
    { "toggle",                             function() return require("crates.core").toggle() end },
    { "update",                             function() return require("crates.core").update() end },
    { "reload",                             function() return require("crates.core").reload() end },

    { "upgrade_crate",                      function() return require("crates.actions").upgrade_crate() end },
    { "upgrade_crates",                     function() return require("crates.actions").upgrade_crates() end },
    { "upgrade_all_crates",                 function() return require("crates.actions").upgrade_all_crates() end },
    { "update_crate",                       function() return require("crates.actions").update_crate() end },
    { "update_crates",                      function() return require("crates.actions").update_crates() end },
    { "update_all_crates",                  function() return require("crates.actions").update_all_crates() end },
    { "use_git_source",                     function() return require("crates.actions").use_git_source() end },

    { "expand_plain_crate_to_inline_table", function() return require("crates.actions").expand_plain_crate_to_inline_table() end },
    { "extract_crate_into_table",           function() return require("crates.actions").extract_crate_into_table() end },

    { "open_homepage",                      function() return require("crates.actions").open_homepage() end },
    { "open_repository",                    function() return require("crates.actions").open_repository() end },
    { "open_documentation",                 function() return require("crates.actions").open_documentation() end },
    { "open_cratesio",                      function() return require("crates.actions").open_crates_io() end },

    { "popup_available",                    function() return require("crates.popup").available() end },
    { "show_popup",                         function() return require("crates.popup").show() end },
    { "show_crate_popup",                   function() return require("crates.popup").show_crate() end },
    { "show_versions_popup",                function() return require("crates.popup").show_versions() end },
    { "show_features_popup",                function() return require("crates.popup").show_features() end },
    { "show_dependencies_popup",            function() return require("crates.popup").show_dependencies() end },
    { "focus_popup",                        function() return require("crates.popup").focus() end },
    { "hide_popup",                         function() return require("crates.popup").hide() end },
}

---@param arglead string
---@param line string
---@return string[]
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

---@param cmd table<string,any>
local function exec(cmd)
    for _, s in ipairs(sub_commands) do
        if s[1] == cmd.args then
            local fn = s[2]
            ---@type any
            local ret = fn()
            if ret ~= nil then
                print(vim.inspect(ret))
            end
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
