local M = {}

function M.default()
    return {
        autoload = true,
        autoupdate = true,
        loading_indicator = true,
        popup_hide_keys = { "q", "<esc>" },
        text = {
            version = "%s",
            loading = "Loading...",
            error = "Error fetching version",
        },
        highlight = {
            loading = "CratesNvimLoading",
            version = "CratesNvimVersion",
            error = "CratesNvimError",
        },
        win_style = "minimal",
        win_border = "none",
    }
end

function M.extend_with_default(config)
    local default = M.default()

    for k,v in pairs(default) do
        if not config[k] then
            config[k] = v
        end
    end
end

return M
