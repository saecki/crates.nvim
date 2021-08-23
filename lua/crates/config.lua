local M = {}

function M.default()
    return {
        loading_indicator = true,
        text = {
            version = "%s",
            loading = "Loading...",
            error = "Error fetching version",
        },
        highlight = {
            loading = "CratesNvimLoading",
            version = "CratesNvimVersion",
            error = "CratesNvimError",
        }
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
