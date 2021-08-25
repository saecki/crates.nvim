local M = {}

function M.default()
    return {
        autoload = true,
        autoupdate = true,
        loading_indicator = true,
        text = {
            loading = "Loading...",
            version = "%s",
            update = "  %s",
            error = "Error fetching version",
            yanked = "%s yanked",
        },
        highlight = {
            loading = "CratesNvimLoading",
            version = "CratesNvimVersion",
            update = "CratesNvimUpdate",
            error = "CratesNvimError",
            yanked = "CratesNvimYanked"
        },
        popup = {
            text = {
                yanked = "yanked"
            },
            highlight = {
                yanked = "CratesNvimPopupYanked"
            },
            keys = {
                hide = { "q", "<esc>" },
                copy_version = { "yy" },
            },
            style = "minimal",
            border = "none",
            max_height = 30,
            min_width = 20,
        },
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
