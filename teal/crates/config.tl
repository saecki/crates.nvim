local record Config
    smart_insert: boolean
    avoid_prerelease: boolean
    autoload: boolean
    autoupdate: boolean
    loading_indicator: boolean
    date_format: string
    text: TextConfig
    highlight: HighlightConfig
    popup: PopupConfig
    cmp: CmpConfig

    record TextConfig
        loading: string
        version: string
        prerelease: string
        yanked: string
        nomatch: string
        upgrade: string
        error: string
    end

    record HighlightConfig
        loading: string
        version: string
        prerelease: string
        yanked: string
        nomatch: string
        upgrade: string
        error: string
    end

    record PopupConfig
        autofocus: boolean
        copy_register: string
        style: string
        border: string|{string}
        version_date: boolean
        max_height: integer
        min_width: integer
        text: PopupTextConfig
        highlight: PopupHighlightConfig
        keys: PopupKeyConfig

    end

    record PopupTextConfig
        title: string
        version: string
        prerelease: string
        yanked: string
        feature: string
        enabled: string
        transitive: string
        date: string
    end

    record PopupHighlightConfig
        title: string
        version: string
        prerelease: string
        yanked: string
        feature: string
        enabled: string
        transitive: string
    end

    record PopupKeyConfig
        hide: {string}
        select: {string}
        select_dumb: {string}
        copy_version: {string}
        toggle_feature: {string}
        goto_feature: {string}
        jump_forward_feature: {string}
        jump_back_feature: {string}
    end

    record CmpConfig
        text: CmpTextConfig
    end

    record CmpTextConfig
        prerelease: string
        yanked: string
    end
end

function Config.default(): Config
    return {
        smart_insert = true, -- try to be smart about inserting versions
        avoid_prerelease = true, -- don't select a prerelease if the requirement does not have a suffix
        autoload = true, -- automatically run update when opening a Cargo.toml
        autoupdate = true, -- automatically update when editing text
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
                toggle_feature = { "<cr>" },
                goto_feature = { "gd", "K" },
                jump_forward_feature = { "<c-i>" },
                jump_back_feature = { "<c-o>" },
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

return Config
