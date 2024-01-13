local record M end

local actions = require("crates.actions")
local core = require("crates.core")
local popup = require("crates.popup")

local sub_commands: {{string,function}} = {
    { "hide", core.hide },
    { "show", core.show },
    { "toggle", core.toggle },
    { "update", core.update },
    { "reload", core.reload },

    { "upgrade_crate", actions.upgrade_crate },
    { "upgrade_crates", actions.upgrade_crates },
    { "upgrade_all_crates", actions.upgrade_all_crates },
    { "update_crate", actions.update_crate },
    { "update_crates", actions.update_crates },
    { "update_all_crates", actions.update_all_crates },

    { "expand_to_inline_table", actions.expand_plain_crate_to_inline_table },
    { "extract_into_table", actions.extract_crate_into_table },

    { "open_homepage", actions.open_homepage },
    { "open_repository", actions.open_repository },
    { "open_documentation", actions.open_documentation },
    { "open_cratesio", actions.open_crates_io },

    { "popup_available", popup.available },
    { "show_popup", popup.show },
    { "show_crate_popup", popup.show_crate },
    { "show_versions_popup", popup.show_versions },
    { "show_features_popup", popup.show_features },
    { "show_dependencies_popup", popup.show_dependencies },
    { "focus_popup", popup.focus },
    { "hide_popup", popup.hide },
}

local function complete(arglead: string, line: string): {string}
    local matches = {}

    local words = vim.split(line, "%s+")
    if #words > 2 then
        return matches
    end

    for _,s in ipairs(sub_commands) do
        if vim.startswith(s[1], arglead) then
            table.insert(matches, s[1])
        end
    end
    return matches
end

local function exec(cmd: {string:any})
    for _,s in ipairs(sub_commands) do
        if s[1] == cmd.args then
            local ret = s[2]()
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
