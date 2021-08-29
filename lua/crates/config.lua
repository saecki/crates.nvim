local M = {}

function M.default()
    return {
        avoid_prerelease = true,
        autoload = true,
        autoupdate = true,
        loading_indicator = true,
        text = {
            loading = "   Loading",
            version = "   %s",
            prerelease = "   %s",
            yanked = "   %s",
            nomatch = "   No match",
            update = "   %s",
            error = "   Error fetching crate",
        },
        highlight = {
            loading = "CratesNvimLoading",
            version = "CratesNvimVersion",
            prerelease = "CratesNvimPreRelease",
            yanked = "CratesNvimYanked",
            nomatch = "CratesNvimNoMatch",
            update = "CratesNvimUpdate",
            error = "CratesNvimError",
        },
        popup = {
            autofocus = false,
            text = {
                yanked = " "
            },
            highlight = {
                yanked = "CratesNvimPopupYanked"
            },
            keys = {
                hide = { "q", "<esc>" },
                select = { "<cr>" },
                copy_version = { "yy" },
            },
            style = "minimal",
            border = "none",
            max_height = 30,
            min_width = 20,
        },
    }
end

return M
