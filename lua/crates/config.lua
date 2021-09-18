---@class Config
---@field smart_insert boolean
---@field avoid_prerelease boolean
---@field autoload boolean
---@field autoupdate boolean
---@field loading_indicator boolean
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
---@field update string
---@field error string

---@class HighlightConfig
---@field loading string
---@field version string
---@field prerelease string
---@field yanked string
---@field nomatch string
---@field update string
---@field error string

---@class PopupConfig
---@field autofocus boolean
---@field copy_register string
---@field style string
---@field border string | string[]
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

---@class PopupHighlightConfig
---@field title string
---@field version string
---@field prerelease string
---@field yanked string
---@field feature string

---@class PopupKeyConfig
---@field hide string[]
---@field select string[]
---@field select_dumb string[]
---@field copy_version string[]

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
        text = {
            loading    = "   Loading",
            version    = "   %s",
            prerelease = "   %s",
            yanked     = "   %s",
            nomatch    = "   No match",
            update     = "   %s",
            error      = "   Error fetching crate",
        },
        highlight = {
            loading    = "CratesNvimLoading",
            version    = "CratesNvimVersion",
            prerelease = "CratesNvimPreRelease",
            yanked     = "CratesNvimYanked",
            nomatch    = "CratesNvimNoMatch",
            update     = "CratesNvimUpdate",
            error      = "CratesNvimError",
        },
        popup = {
            autofocus = false, -- focus the versions popup when opening it
            copy_register = '"', -- the register into which the version will be copied
            style = "minimal", -- same as nvim_open_win config.style
            border = "none", -- same as nvim_open_win config.border
            max_height = 30,
            min_width = 20,
            text = {
                title      = "  %s ",
                version    = "   %s ",
                prerelease = "  %s ",
                yanked     = "  %s ",
                feature    = "   %s ",
            },
            highlight = {
                title      = "CratesNvimPopupTitle",
                version    = "CratesNvimPopupVersion",
                prerelease = "CratesNvimPopupPreRelease",
                yanked     = "CratesNvimPopupYanked",
                feature    = "CratesNvimPopupFeature",
            },
            keys = {
                hide = { "q", "<esc>" },
                select = { "<cr>" },
                select_dumb = { "s" },
                copy_version = { "yy" },
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
