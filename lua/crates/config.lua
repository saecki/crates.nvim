---@class Config
---@field smart_insert boolean
---@field avoid_prerelease boolean
---@field autoload boolean
---@field autoupdate boolean
---@field loading_indicator boolean
---@field date_format string
---@field text TextConfig
---@field highlight HighlightConfig
---@field popup PopupConfig
---@field cmp CmpConfig

---@class TextConfig
---@field loading string
---@field version string
---@field prerelease string
---@field yanked string
---@field nomatch string
---@field upgrade string
---@field error string

---@class HighlightConfig
---@field loading string
---@field version string
---@field prerelease string
---@field yanked string
---@field nomatch string
---@field upgrade string
---@field error string

---@class PopupConfig
---@field autofocus boolean
---@field copy_register string
---@field style string
---@field border string | string[]
---@field version_date boolean
---@field max_height integer
---@field min_width integer
---@field text PopupTextConfig
---@field highlight PopupHighlightConfig
---@field keys PopupKeyConfig

---@class PopupTextConfig
---@field title string
---@field version string
---@field prerelease string
---@field yanked string
---@field feature string
---@field enabled string
---@field transitive string
---@field date string

---@class PopupHighlightConfig
---@field title string
---@field version string
---@field prerelease string
---@field yanked string
---@field feature string
---@field enabled string
---@field transitive string

---@class PopupKeyConfig
---@field hide string[]
---@field select string[]
---@field select_dumb string[]
---@field copy_version string[]
---@field goto_feature string[]
---@field goback_feature string[]

---@class CmpConfig
---@field text CmpTextConfig

---@class CmpTextConfig
---@field prerelease string
---@field yanked string

local M = {}

---@return Config
function M.default()
    return {
        smart_insert = true, -- try to be smart about inserting versions
        avoid_prerelease = true, -- don't select a prerelease if the requirement does not have a suffix
        autoload = true, -- automatically run update when opening a Cargo.toml
        autoupdate = true, -- atomatically update when editing text
        loading_indicator = true, -- show a loading indicator while fetching crate versions
        date_format = "%Y-%m-%d", -- the date format passed to os.date
        text = {
            loading    = "   Loading",
            version    = "   %s",
            prerelease = "   %s",
            yanked     = "   %s",
            nomatch    = "   No match",
            upgrade    = "   %s",
            error      = "   Error fetching crate",
        },
        highlight = {
            loading    = "CratesNvimLoading",
            version    = "CratesNvimVersion",
            prerelease = "CratesNvimPreRelease",
            yanked     = "CratesNvimYanked",
            nomatch    = "CratesNvimNoMatch",
            upgrade    = "CratesNvimUpgrade",
            error      = "CratesNvimError",
        },
        popup = {
            autofocus = false, -- focus the versions popup when opening it
            copy_register = '"', -- the register into which the version will be copied
            style = "minimal", -- same as nvim_open_win config.style
            border = "none", -- same as nvim_open_win config.border
            version_date = false, -- display when a version was released
            max_height = 30,
            min_width = 20,
            text = {
                title      = "  %s ",
                -- versions
                version    = "   %s ",
                prerelease = "  %s ",
                yanked     = "  %s ",
                -- features
                feature    = "   %s ",
                enabled    = "  %s ",
                transitive = "  %s ",
                date       = " %s ",
            },
            highlight = {
                title      = "CratesNvimPopupTitle",
                -- versions
                version    = "CratesNvimPopupVersion",
                prerelease = "CratesNvimPopupPreRelease",
                yanked     = "CratesNvimPopupYanked",
                -- features
                feature    = "CratesNvimPopupFeature",
                enabled    = "CratesNvimPopupEnabled",
                transitive = "CratesNvimPopupTransitive",
            },
            keys = {
                hide = { "q", "<esc>" },
                -- versions
                select = { "<cr>" },
                select_dumb = { "s" },
                copy_version = { "yy" },
                -- features
                goto_feature = { "K", "<c-i>" },
                goback_feature = { "<c-o>" },
            },
        },
        cmp = {
            text = {
                prerelease = "  pre-release ",
                yanked     = "  yanked ",
            },
        },
    }
end

return M
