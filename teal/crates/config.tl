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
        description = "try to be smart about inserting versions",
    },
    avoid_prerelease = {
        type = "boolean",
        default = true,
        description = "don't select a prerelease if the requirement does not have a suffix",
    },
    autoload = {
        type = "boolean",
        default = true,
        description = "automatically run update when opening a Cargo.toml",
    },
    autoupdate = {
        type = "boolean",
        default = true,
        description = "automatically update when editing text",
    },
    loading_indicator = {
        type = "boolean",
        default = true,
        description = "show a loading indicator while fetching crate versions",
    },
    date_format = {
        type = "string",
        default = "%Y-%m-%d",
        description = "the date format passed to os.date",
    },
    text = {
        type = "section",

        fields = {
            loading = {
                type = "string",
                default = "   Loading",
            },
            version = {
                type = "string",
                default = "   %s",
            },
            prerelease = {
                type = "string",
                default = "   %s",
            },
            yanked = {
                type = "string",
                default = "   %s",
            },
            nomatch = {
                type = "string",
                default = "   No match",
            },
            upgrade = {
                type = "string",
                default = "   %s",
            },
            error = {
                type = "string",
                default = "   Error fetching crate",
            },

            update = {
                type = "string",
                deprecated = {
                    new_field = { "text", "upgrade" },
                    hard = true,
                },
            },
        },
    },
    highlight = {
        type = "section",

        fields = {
            loading = {
                type = "string",
                default = "CratesNvimLoading",
            },
            version = {
                type = "string",
                default = "CratesNvimVersion",
            },
            prerelease = {
                type = "string",
                default = "CratesNvimPreRelease",
            },
            yanked = {
                type = "string",
                default = "CratesNvimYanked",
            },
            nomatch = {
                type = "string",
                default = "CratesNvimNoMatch",
            },
            upgrade = {
                type = "string",
                default = "CratesNvimUpgrade",
            },
            error = {
                type = "string",
                default = "CratesNvimError",
            },

            update = {
                type = "string",
                deprecated = {
                    new_field = { "highlight", "upgrade" },
                    hard = true,
                },
            },
        },
    },
    popup = {
        type = "section",

        fields = {
            autofocus = {
                type = "boolean",
                default = false,
                description = "focus the versions popup when opening it",
            },
            copy_register = {
                type = "string",
                default = '"',
                description = "the register into which the version will be copied",
            },
            style = {
                type = "string",
                default = "minimal",
                description = "same as nvim_open_win config.style",
            },
            border = {
                type = { "string", "table" },
                default = "none",
                description = "same as nvim_open_win config.border",
            },
            version_date = {
                type = "boolean",
                default = false,
                description = "display when a version was released",
            },
            max_height = {
                type = "number",
                default = 30,
            },
            min_width = {
                type = "number",
                default = 20,
            },
            text = {
                type = "section",

                fields = {
                    title = {
                        type = "string",
                        default = "  %s ",
                    },

                    -- versions
                    version = {
                        type = "string",
                        default = "   %s ",
                    },
                    prerelease = {
                        type = "string",
                        default = "  %s ",
                    },
                    yanked = {
                        type = "string",
                        default = "  %s ",
                    },

                    -- features
                    feature = {
                        type = "string",
                        default = "   %s ",
                    },
                    enabled = {
                        type = "string",
                        default = "  %s ",
                    },
                    transitive = {
                        type = "string",
                        default = "  %s ",
                    },
                    date = {
                        type = "string",
                        default = " %s ",
                    },
                },
            },
            highlight = {
                type = "section",

                fields = {
                    title = {
                        type = "string",
                        default = "CratesNvimPopupTitle",
                    },

                    -- versions
                    version = {
                        type = "string",
                        default = "CratesNvimPopupVersion",
                    },
                    prerelease = {
                        type = "string",
                        default = "CratesNvimPopupPreRelease",
                    },
                    yanked = {
                        type = "string",
                        default = "CratesNvimPopupYanked",
                    },

                    -- features
                    feature = {
                        type = "string",
                        default = "CratesNvimPopupFeature",
                    },
                    enabled = {
                        type = "string",
                        default = "CratesNvimPopupEnabled",
                    },
                    transitive = {
                        type = "string",
                        default = "CratesNvimPopupTransitive",
                    },
                },
            },
            keys = {
                type = "section",

                fields = {
                    hide = {
                        type = "table",
                        default = { "q", "<esc>" },
                    },

                    -- versions
                    select = {
                        type = "table",
                        default = { "<cr>" },
                    },
                    select_alt = {
                        type = "table",
                        default = { "s" },
                    },
                    copy_version = {
                        type = "table",
                        default = { "yy" },
                    },

                    -- features
                    toggle_feature = {
                        type = "table",
                        default = { "<cr>" },
                    },
                    goto_feature = {
                        type = "table",
                        default = { "gd", "K" },
                    },
                    jump_forward_feature = {
                        type = "table",
                        default = { "<c-i>" },
                    },
                    jump_back_feature = {
                        type = "table",
                        default = { "<c-o>" },
                    },
                },
            },
        },
    },
    cmp = {
        type = "section",

        fields = {
            text = {
                type = "section",

                fields = {
                    prerelease = {
                        type = "string",
                        default = "  pre-release ",
                    },
                    yanked = {
                        type = "string",
                        default = "  yanked ",
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
