local record M
    schema: {string:SchemaElement}

    record Config
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
            select_alt: {string}
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

    enum SchemaType
        "section"
        "table"
        "string"
        "number"
        "boolean"
    end

    record SchemaElement
        type: SchemaType|{SchemaType}
        default: any
        default_text: string
        description: string
        deprecated: Deprecated
        fields: {string:SchemaElement}

        record Deprecated
            new_field: {string}
            hard: boolean
        end
    end
end

local Config = M.Config
local SchemaType = M.SchemaType
local SchemaElement = M.SchemaElement

M.schema = {
    smart_insert = {
        type = "boolean",
        default = true,
        description = [[
            Try to be smart about inserting versions, by respecting existing version requirements.

            Example: ~
                Existing requirement:
                `>0.8, <1.3`

                Version to insert:
                `1.5.4`

                Resulting requirement:
                `>0.1, <1.6`
        ]],
    },
    avoid_prerelease = {
        type = "boolean",
        default = true,
        description = [[
            Don't select a prerelease if the requirement does not have a suffix.
        ]],
    },
    autoload = {
        type = "boolean",
        default = true,
        description = [[
            Automatically run update when opening a Cargo.toml.
        ]],
    },
    autoupdate = {
        type = "boolean",
        default = true,
        description = [[
            Automatically update when editing text.
        ]],
    },
    loading_indicator = {
        type = "boolean",
        default = true,
        description = [[
            Show a loading indicator while fetching crate versions.
        ]],
    },
    date_format = {
        type = "string",
        default = "%Y-%m-%d",
        description = [[
            The date format passed to `os.date`.
        ]],
    },
    text = {
        type = "section",
        description = [[
            Strings used to format virtual text.
        ]],

        fields = {
            loading = {
                type = "string",
                default = "   Loading",
                description = [[
                    Format string used while loading crate information.
                ]],
            },
            version = {
                type = "string",
                default = "   %s",
                description = [[
                    format string used for the latest compatible version
                ]],
            },
            prerelease = {
                type = "string",
                default = "   %s",
                description = [[
                    Format string used for pre-release versions.
                ]],
            },
            yanked = {
                type = "string",
                default = "   %s",
                description = [[
                    Format string used for yanked versions.
                ]],
            },
            nomatch = {
                type = "string",
                default = "   No match",
                description = [[
                    Format string used when there is no matching version.
                ]],
            },
            upgrade = {
                type = "string",
                default = "   %s",
                description = [[
                    Format string used when there is an upgrade candidate.
                ]],
            },
            error = {
                type = "string",
                default = "   Error fetching crate",
                description = [[
                    Format string used when there was an error loading crate information.
                ]],
            },

            update = {
                type = "string",
                deprecated = {
                    new_field = { "text", "upgrade" },
                    hard = true,
                },
                description = [[
                    See *crates-config-text-upgrade*.
                ]],
            },
        },
    },
    highlight = {
        type = "section",
        description = [[
            Highlight groups used for virtual text.
        ]],

        fields = {
            loading = {
                type = "string",
                default = "CratesNvimLoading",
                description = [[
                    Highlight group used while loading crate information.
                ]],
            },
            version = {
                type = "string",
                default = "CratesNvimVersion",
                description = [[
                    Highlight group used for the latest compatible version.
                ]],
            },
            prerelease = {
                type = "string",
                default = "CratesNvimPreRelease",
                description = [[
                    Highlight group used for pre-release versions.
                ]],
            },
            yanked = {
                type = "string",
                default = "CratesNvimYanked",
                description = [[
                    Highlight group used for yanked versions.
                ]],
            },
            nomatch = {
                type = "string",
                default = "CratesNvimNoMatch",
                description = [[
                    Highlight group used when there is no matching version.
                ]],
            },
            upgrade = {
                type = "string",
                default = "CratesNvimUpgrade",
                description = [[
                    Highlight group used when there is an upgrade candidate.
                ]],
            },
            error = {
                type = "string",
                default = "CratesNvimError",
                description = [[
                    Highlight group used when there was an error loading crate information.
                ]],
            },

            update = {
                type = "string",
                deprecated = {
                    new_field = { "highlight", "upgrade" },
                    hard = true,
                },
                description = [[
                    See *crates-config-highlight-upgrade*.
                ]],
            },
        },
    },
    popup = {
        type = "section",
        description = [[
            popup config
        ]],

        fields = {
            autofocus = {
                type = "boolean",
                default = false,
                description = [[
                    Focus the versions popup when opening it.
                ]],
            },
            copy_register = {
                type = "string",
                default = '"',
                description = [[
                    The register into which the version will be copied.
                ]],
            },
            style = {
                type = "string",
                default = "minimal",
                description = [[
                    Same as nvim_open_win config.style.
                ]],
            },
            border = {
                type = { "string", "table" },
                default = "none",
                description = [[
                    Same as nvim_open_win config.border.
                ]],
            },
            version_date = {
                type = "boolean",
                default = false,
                description = [[
                    Display when a version was released.
                ]],
            },
            max_height = {
                type = "number",
                default = 30,
                description = [[
                    The maximum height of the popup.
                ]],
            },
            min_width = {
                type = "number",
                default = 20,
                description = [[
                    The minimum width of the popup.
                ]],
            },
            text = {
                type = "section",
                description = [[
                    Strings used to format the text inside the popup.
                ]],

                fields = {
                    title = {
                        type = "string",
                        default = "  %s ",
                        description = [[
                            Format string used for the popup title.
                        ]],
                    },

                    -- versions
                    version = {
                        type = "string",
                        default = "   %s ",
                        description = [[
                            Format string used for release versions.
                        ]],
                    },
                    prerelease = {
                        type = "string",
                        default = "  %s ",
                        description = [[
                            Format string used for prerelease versions.
                        ]],
                    },
                    yanked = {
                        type = "string",
                        default = "  %s ",
                        description = [[
                            Format string used for yanked versions.
                        ]],
                    },
                    date = {
                        type = "string",
                        default = " %s ",
                        description = [[
                            Format string used for appending the version release date.
                        ]],
                    },

                    -- features
                    feature = {
                        type = "string",
                        default = "   %s ",
                        description = [[
                            Format string used for disabled features.
                        ]],
                    },
                    enabled = {
                        type = "string",
                        default = "  %s ",
                        description = [[
                            Format string used for enabled features.
                        ]],
                    },
                    transitive = {
                        type = "string",
                        default = "  %s ",
                        description = [[
                            Format string used for transitively enabled features.
                        ]],
                    },
                },
            },
            highlight = {
                type = "section",
                description = [[
                    Highlight groups for popup elements.
                ]],

                fields = {
                    title = {
                        type = "string",
                        default = "CratesNvimPopupTitle",
                        description = [[
                            TODO ~
                        ]],
                    },

                    -- versions
                    version = {
                        type = "string",
                        default = "CratesNvimPopupVersion",
                        description = [[
                            TODO ~
                        ]],
                    },
                    prerelease = {
                        type = "string",
                        default = "CratesNvimPopupPreRelease",
                        description = [[
                            TODO ~
                        ]],
                    },
                    yanked = {
                        type = "string",
                        default = "CratesNvimPopupYanked",
                        description = [[
                            TODO ~
                        ]],
                    },

                    -- features
                    feature = {
                        type = "string",
                        default = "CratesNvimPopupFeature",
                        description = [[
                            TODO ~
                        ]],
                    },
                    enabled = {
                        type = "string",
                        default = "CratesNvimPopupEnabled",
                        description = [[
                            TODO ~
                        ]],
                    },
                    transitive = {
                        type = "string",
                        default = "CratesNvimPopupTransitive",
                        description = [[
                            TODO ~
                        ]],
                    },
                },
            },
            keys = {
                type = "section",
                description = [[
                    Key mappings inside the popup.
                ]],

                fields = {
                    hide = {
                        type = "table",
                        default = { "q", "<esc>" },
                        description = [[
                            Hides the popup.
                        ]],
                    },

                    -- versions
                    select = {
                        type = "table",
                        default = { "<cr>" },
                        description = [[
                            Insert the version respecting the |crates-config-smart_insert| flag.
                        ]],
                    },
                    select_alt = {
                        type = "table",
                        default = { "s" },
                        description = [[
                            Insert the version using the opposite of |crates-config-smart_insert| flag.
                        ]],
                    },
                    copy_version = {
                        type = "table",
                        default = { "yy" },
                        description = [[
                            TODO ~
                        ]],
                    },

                    -- features
                    toggle_feature = {
                        type = "table",
                        default = { "<cr>" },
                        description = [[
                            TODO ~
                        ]],
                    },
                    goto_feature = {
                        type = "table",
                        default = { "gd", "K" },
                        description = [[
                            TODO ~
                        ]],
                    },
                    jump_forward_feature = {
                        type = "table",
                        default = { "<c-i>" },
                        description = [[
                            TODO ~
                        ]],
                    },
                    jump_back_feature = {
                        type = "table",
                        default = { "<c-o>" },
                        description = [[
                            TODO ~
                        ]],
                    },
                },
            },
        },
    },
    cmp = {
        type = "section",
        description = [[
            TODO ~
        ]],

        fields = {
            text = {
                type = "section",
                description = [[
                    TODO ~
                ]],

                fields = {
                    prerelease = {
                        type = "string",
                        default = "  pre-release ",
                        description = [[
                            TODO ~
                        ]],
                    },
                    yanked = {
                        type = "string",
                        default = "  yanked ",
                        description = [[
                            TODO ~
                        ]],
                    },
                },
            },
        },
    },
}

local function warn(s: string, ...:any)
    vim.notify(s:format(...), vim.log.levels.WARN, { title = "crates.nvim" })
end

local function join_path(path: {string}, component: string): {string}
    local p = {}
    for i,c in ipairs(path) do
        p[i] = c
    end
    table.insert(p, component)
    return p
end

local function table_set_path(t: {string:any}, path: {string}, value: any)
    local current = t
    for i,c in ipairs(path) do
        if i == #path then
            current[c] = value
        elseif type(current[c]) == "table" then
            current = current[c] as {string:any}
        elseif current[c] == nil then
            current[c] = {}
            current = current[c] as {string:any}
        else
            break -- don't overwrite existing value
        end
    end
end

local function handle_deprecated(path: {string}, schema: {string:SchemaElement}, root_config: {string:any}, user_config: {string:any})
    for k,v in pairs(user_config) do
        local elem = schema[k]

        if elem then
            local p = join_path(path, k)
            local dep = elem.deprecated

            if dep then
                if dep.new_field and not dep.hard then
                    table_set_path(root_config, dep.new_field, v)
                end
            elseif elem.type == "section" and type(v) == "table" then
                handle_deprecated(p, elem.fields, root_config, v as {string:any})
            end
        end
    end
end

local function validate_schema(path: {string}, schema: {string:SchemaElement}, user_config: {string:any})
    for k,v in pairs(user_config) do
        local p = join_path(path, k)
        local elem = schema[k]

        if elem then
            local value_type = type(v)
            local dep = elem.deprecated

            if dep then
                if dep.new_field then
                    local dep_text: string
                    if dep.hard then
                        dep_text = "deprecated and won't work anymore"
                    else
                        dep_text = "deprecated and will stop working soon"
                    end

                    warn(
                        "'%s' is now %s, please use '%s'",
                        table.concat(p, "."),
                        dep_text,
                        table.concat(dep.new_field, ".")
                    )
                else
                    warn(
                        "'%s' is now deprecated, ignoring",
                        table.concat(p, ".")
                    )
                end
            elseif elem.type == "section" then
                if value_type == "table" then
                    validate_schema(p, elem.fields, v as {string:any})
                else
                    warn(
                        "Config field '%s' was expected to be of type 'table' but was '%s', using default value.",
                        table.concat(p, "."),
                        value_type
                    )
                end
            else
                local elem_types: {SchemaType}
                if type(elem.type) == "string" then
                    elem_types = { elem.type as SchemaType }
                else
                    elem_types = elem.type as { SchemaType }
                end

                if not vim.tbl_contains(elem_types, value_type as SchemaType) then
                    warn(
                        "Config field '%s' was expected to be of type '%s' but was '%s', using default value.",
                        table.concat(p, "."),
                        table.concat(elem_types, " or "),
                        value_type
                    )
                end
            end
        else
            warn(
                "Ignoring invalid config key '%s'",
                table.concat(p, ".")
            )
        end
    end
end

local function build_config(schema: {string:SchemaElement}, user_config: {string:any}): table
    local config: {string:any} = {}

    for k,elem in pairs(schema) do
        local v = user_config[k]
        local value_type = type(v)

        if elem.type == "section" then
            if value_type == "table" then
                config[k] = build_config(elem.fields, v as {string:any})
            else
                config[k] = build_config(elem.fields, {})
            end
        else
            local elem_types: {SchemaType}
            if type(elem.type) == "string" then
                elem_types = { elem.type as SchemaType }
            else
                elem_types = elem.type as { SchemaType }
            end

            if vim.tbl_contains(elem_types, value_type as SchemaType) then
                config[k] = v
            else
                config[k] = elem.default
            end
        end
    end

    return config
end

function M.build(user_config: {string:any}): Config
    user_config = user_config or {}
    local config_type = type(user_config)
    if config_type ~= "table" then
        warn("Expected config of type 'table' found '%s'", config_type)
        user_config = {}
    end

    handle_deprecated({}, M.schema, user_config, user_config)

    validate_schema({}, M.schema, user_config)

    return build_config(M.schema, user_config) as Config
end


return M
