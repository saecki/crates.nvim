local record M
    schema: {string:SchemaElement}

    record Config
        smart_insert: boolean
        insert_closing_quote: boolean
        avoid_prerelease: boolean
        autoload: boolean
        autoupdate: boolean
        loading_indicator: boolean
        date_format: string
        thousands_separator: string
        notification_title: string
        curl_args: {string}
        disable_invalid_feature_diagnostic: boolean
        text: TextConfig
        highlight: HighlightConfig
        diagnostic: DiagnosticConfig
        popup: PopupConfig
        src: SrcConfig
        null_ls: NullLsConfig

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

        record DiagnosticConfig
            section_invalid: string
            workspace_section_not_default: string
            workspace_section_has_target: string
            section_dup: string
            section_dup_orig: string
            crate_dup: string
            crate_dup_orig: string
            crate_novers: string
            crate_error_fetching: string
            vers_upgrade: string
            vers_pre: string
            vers_yanked: string
            vers_nomatch: string
            def_invalid: string
            feat_dup: string
            feat_dup_orig: string
            feat_invalid: string
        end

        record PopupConfig
            autofocus: boolean
            copy_register: string
            style: string
            border: string|{string}
            show_version_date: boolean
            show_dependency_version: boolean
            max_height: integer
            min_width: integer
            padding: integer
            text: PopupTextConfig
            highlight: PopupHighlightConfig
            keys: PopupKeyConfig
        end

        record PopupTextConfig
            title: string
            pill_left: string
            pill_right: string

            description: string
            created: string
            created_label: string
            updated: string
            updated_label: string
            downloads: string
            downloads_label: string
            homepage: string
            homepage_label: string
            repository: string
            repository_label: string
            documentation: string
            documentation_label: string
            crates_io: string
            crates_io_label: string
            categories_label: string
            keywords_label: string

            version: string
            prerelease: string
            yanked: string
            version_date: string

            feature: string
            enabled: string
            transitive: string

            normal_dependencies_title: string
            build_dependencies_title: string
            dev_dependencies_title: string
            dependency: string
            optional: string
            dependency_version: string
            loading: string
        end

        record PopupHighlightConfig
            title: string
            pill_text: string
            pill_border: string

            created: string
            created_label: string
            updated: string
            updated_label: string
            description: string
            downloads: string
            downloads_label: string
            homepage: string
            homepage_label: string
            repository: string
            repository_label: string
            documentation: string
            documentation_label: string
            crates_io: string
            crates_io_label: string
            categories_label: string
            keywords_label: string

            version: string
            prerelease: string
            yanked: string
            version_date: string

            feature: string
            enabled: string
            transitive: string

            normal_dependencies_title: string
            build_dependencies_title: string
            dev_dependencies_title: string
            dependency: string
            optional: string
            dependency_version: string
            loading: string
        end

        record PopupKeyConfig
            hide: {string}
            open_url: {string}
            select: {string}
            select_alt: {string}
            toggle_feature: {string}
            copy_value: {string}
            goto_item: {string}
            jump_forward: {string}
            jump_back: {string}
        end

        record SrcConfig
            insert_closing_quote: boolean
            text: SrcTextConfig
            coq: CoqConfig
        end

        record SrcTextConfig
            prerelease: string
            yanked: string
        end

        record CoqConfig
            enabled: boolean
            name: string
        end

        record NullLsConfig
            enabled: boolean
            name: string
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
        name: string
        type: SchemaType|{SchemaType}
        default: any
        default_text: string
        description: string
        deprecated: Deprecated
        fields: {string:SchemaElement}
        hidden: boolean

        record Deprecated
            new_field: {string}
            hard: boolean
        end
    end
end

local Config = M.Config
local SchemaElement = M.SchemaElement
local SchemaType = M.SchemaType

local function entry(schema: {string:SchemaElement}, name: string, elem: SchemaElement)
    elem.name = name
    table.insert(schema as {SchemaElement}, elem)
    schema[name] = elem
end

M.schema = {}
entry(M.schema, "smart_insert", {
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
            `>0.8, <1.6`
    ]],
})
entry(M.schema, "insert_closing_quote", {
    type = "boolean",
    default = true,
    description = [[
        Insert a closing quote when updating or upgrading a version, if there is none.
    ]],
})
entry(M.schema, "avoid_prerelease", {
    type = "boolean",
    default = true,
    description = [[
        Don't select a prerelease if the requirement does not have a suffix.
    ]],
})
entry(M.schema, "autoload", {
    type = "boolean",
    default = true,
    description = [[
        Automatically run update when opening a Cargo.toml.
    ]],
})
entry(M.schema, "autoupdate", {
    type = "boolean",
    default = true,
    description = [[
        Automatically update when editing text.
    ]],
})
entry(M.schema, "loading_indicator", {
    type = "boolean",
    default = true,
    description = [[
        Show a loading indicator while fetching crate versions.
    ]],
})
entry(M.schema, "date_format", {
    type = "string",
    default = "%Y-%m-%d",
    description = [[
        The date format passed to `os.date`.
    ]],
})
entry(M.schema, "thousands_separator", {
    type = "string",
    default = ".",
    description = [[
        The separator used to separate thousands of a number:

        Example: ~
            Dot:
            `14.502.265`

            Comma:
            `14,502,265`
    ]],
})
entry(M.schema, "notification_title", {
    type = "string",
    default = "Crates",
    description = [[
        The title displayed in notifications.
    ]],
})
entry(M.schema, "curl_args", {
    type = "table",
    default = { "-sL", "--retry", "1" },
    description = [[
        The title displayed in notifications.
    ]],
})
-- TODO: use cargo metadata to get feature renames
entry(M.schema, "disable_invalid_feature_diagnostic", {
    type = "boolean",
    default = false,
    description = [[
        This is a temporary solution for:
        https://github.com/Saecki/crates.nvim/issues/14
    ]],
})


entry(M.schema, "text", {
    type = "section",
    description = [[
        Strings used to format virtual text.
    ]],
    fields = {},
})
local schema_text = M.schema.text.fields
entry(schema_text, "loading", {
    type = "string",
    default = "   Loading",
    description = [[
        Format string used while loading crate information.
    ]],
})
entry(schema_text, "version", {
    type = "string",
    default = "   %s",
    description = [[
        format string used for the latest compatible version
    ]],
})
entry(schema_text, "prerelease", {
    type = "string",
    default = "   %s",
    description = [[
        Format string used for pre-release versions.
    ]],
})
entry(schema_text, "yanked", {
    type = "string",
    default = "   %s",
    description = [[
        Format string used for yanked versions.
    ]],
})
entry(schema_text, "nomatch", {
    type = "string",
    default = "   No match",
    description = [[
        Format string used when there is no matching version.
    ]],
})
entry(schema_text, "upgrade", {
    type = "string",
    default = "   %s",
    description = [[
        Format string used when there is an upgrade candidate.
    ]],
})
entry(schema_text, "error", {
    type = "string",
    default = "   Error fetching crate",
    description = [[
        Format string used when there was an error loading crate information.
    ]],
})
-- deprecated
entry(schema_text, "update", {
    type = "string",
    deprecated = {
        new_field = { "text", "upgrade" },
        hard = true,
    },
})


entry(M.schema, "highlight", {
    type = "section",
    description = [[
        Highlight groups used for virtual text.
    ]],
    fields = {},
})
local schema_hi = M.schema.highlight.fields
entry(schema_hi, "loading", {
    type = "string",
    default = "CratesNvimLoading",
    description = [[
        Highlight group used while loading crate information.
    ]],
})
entry(schema_hi, "version", {
    type = "string",
    default = "CratesNvimVersion",
    description = [[
        Highlight group used for the latest compatible version.
    ]],
})
entry(schema_hi, "prerelease", {
    type = "string",
    default = "CratesNvimPreRelease",
    description = [[
        Highlight group used for pre-release versions.
    ]],
})
entry(schema_hi, "yanked", {
    type = "string",
    default = "CratesNvimYanked",
    description = [[
        Highlight group used for yanked versions.
    ]],
})
entry(schema_hi, "nomatch", {
    type = "string",
    default = "CratesNvimNoMatch",
    description = [[
        Highlight group used when there is no matching version.
    ]],
})
entry(schema_hi, "upgrade", {
    type = "string",
    default = "CratesNvimUpgrade",
    description = [[
        Highlight group used when there is an upgrade candidate.
    ]],
})
entry(schema_hi, "error", {
    type = "string",
    default = "CratesNvimError",
    description = [[
        Highlight group used when there was an error loading crate information.
    ]],
})
-- deprecated
entry(schema_hi, "update", {
    type = "string",
    deprecated = {
        new_field = { "highlight", "upgrade" },
        hard = true,
    },
})


entry(M.schema, "diagnostic", {
    type = "section",
    fields = {},
    hidden = true,
})
local schema_diagnostic = M.schema.diagnostic.fields
entry(schema_diagnostic, "section_invalid", {
    type = "string",
    default = "Invalid dependency section",
    hidden = true,
})
entry(schema_diagnostic, "workspace_section_not_default", {
    type = "string",
    default = "Workspace dependency sections don't support other kinds of dependencies like build or dev",
    hidden = true,
})
entry(schema_diagnostic, "workspace_section_has_target", {
    type = "string",
    default = "Workspace dependency sections don't support target specifiers",
    hidden = true,
})
entry(schema_diagnostic, "section_dup", {
    type = "string",
    default = "Duplicate dependency section",
    hidden = true,
})
entry(schema_diagnostic, "section_dup_orig", {
    type = "string",
    default = "Original dependency section is defined here",
    hidden = true,
})
entry(schema_diagnostic, "crate_dup", {
    type = "string",
    default = "Duplicate crate entry",
    hidden = true,
})
entry(schema_diagnostic, "crate_dup_orig", {
    type = "string",
    default = "Original crate entry is defined here",
    hidden = true,
})
entry(schema_diagnostic, "crate_novers", {
    type = "string",
    default = "Missing version requirement",
    hidden = true,
})
entry(schema_diagnostic, "crate_error_fetching", {
    type = "string",
    default = "Error fetching crate versions",
    hidden = true,
})
entry(schema_diagnostic, "vers_upgrade", {
    type = "string",
    default = "There is an upgrade available",
    hidden = true,
})
entry(schema_diagnostic, "vers_pre", {
    type = "string",
    default = "Requirement only matches a pre-release version",
    hidden = true,
})
entry(schema_diagnostic, "vers_yanked", {
    type = "string",
    default = "Requirement only matches a yanked version",
    hidden = true,
})
entry(schema_diagnostic, "vers_nomatch", {
    type = "string",
    default = "Requirement doesn't match a version",
    hidden = true,
})
entry(schema_diagnostic, "def_invalid", {
    type = "string",
    default = "Invalid boolean value",
    hidden = true,
})
entry(schema_diagnostic, "feat_dup", {
    type = "string",
    default = "Duplicate feature entry",
    hidden = true,
})
entry(schema_diagnostic, "feat_dup_orig", {
    type = "string",
    default = "Original feature entry is defined here",
    hidden = true,
})
entry(schema_diagnostic, "feat_invalid", {
    type = "string",
    default = "Invalid feature",
    hidden = true,
})


entry(M.schema, "popup", {
    type = "section",
    description = [[
        popup config
    ]],
    fields = {},
})
local schema_popup = M.schema.popup.fields
entry(schema_popup, "autofocus", {
    type = "boolean",
    default = false,
    description = [[
        Focus the versions popup when opening it.
    ]],
})
entry(schema_popup, "copy_register", {
    type = "string",
    default = '"',
    description = [[
        The register into which the version will be copied.
    ]],
})
entry(schema_popup, "style", {
    type = "string",
    default = "minimal",
    description = [[
        Same as nvim_open_win config.style.
    ]],
})
entry(schema_popup, "border", {
    type = { "string", "table" },
    default = "none",
    description = [[
        Same as nvim_open_win config.border.
    ]],
})
entry(schema_popup, "show_version_date", {
    type = "boolean",
    default = false,
    description = [[
        Display when a version was released.
    ]],
})
entry(schema_popup, "show_dependency_version", {
    type = "boolean",
    default = true,
    description = [[
        Display when a version was released.
    ]],
})
entry(schema_popup, "max_height", {
    type = "number",
    default = 30,
    description = [[
        The maximum height of the popup.
    ]],
})
entry(schema_popup, "min_width", {
    type = "number",
    default = 20,
    description = [[
        The minimum width of the popup.
    ]],
})
entry(schema_popup, "padding", {
    type = "number",
    default = 1,
    description = [[
        The horizontal padding of the popup.
    ]],
})
-- deprecated
entry(schema_popup, "version_date", {
    type = "boolean",
    deprecated = {
        new_field = { "popup", "show_version_date" },
    }
})


entry(schema_popup, "text", {
    type = "section",
    description = [[
        Strings used to format the text inside the popup.
    ]],
    fields = {},
})
local schema_popup_text = schema_popup.text.fields
entry(schema_popup_text, "title", {
    type = "string",
    default = " %s",
    description = [[
        Format string used for the popup title.
    ]],
})
entry(schema_popup_text, "pill_left", {
    type = "string",
    default = "",
    description = [[
        Left border of a pill (keywords and categories).
    ]],
})
entry(schema_popup_text, "pill_right", {
    type = "string",
    default = "",
    description = [[
        Right border of a pill (keywords and categories).
    ]],
})
-- crate
entry(schema_popup_text, "description", {
    type = "string",
    default = "%s",
    description = [[
        Format string used for the description.
    ]],
})
entry(schema_popup_text, "created_label", {
    type = "string",
    default = " created        ",
    description = [[
        Label string used for the creation date.
    ]],
})
entry(schema_popup_text, "created", {
    type = "string",
    default = "%s",
    description = [[
        Format string used for the creation date.
    ]],
})
entry(schema_popup_text, "updated_label", {
    type = "string",
    default = " updated        ",
    description = [[
        Label string used for the updated date.
    ]],
})
entry(schema_popup_text, "updated", {
    type = "string",
    default = "%s",
    description = [[
        Format string used for the updated date.
    ]],
})
entry(schema_popup_text, "downloads_label", {
    type = "string",
    default = " downloads      ",
    description = [[
        Label string used for the download count.
    ]],
})
entry(schema_popup_text, "downloads", {
    type = "string",
    default = "%s",
    description = [[
        Format string used for the download count.
    ]],
})
entry(schema_popup_text, "homepage_label", {
    type = "string",
    default = " homepage       ",
    description = [[
        Label string used for the homepage url.
    ]],
})
entry(schema_popup_text, "homepage", {
    type = "string",
    default = "%s",
    description = [[
        Format string used for the homepage url.
    ]],
})
entry(schema_popup_text, "repository_label", {
    type = "string",
    default = " repository     ",
    description = [[
        Label string used for the repository url.
    ]],
})
entry(schema_popup_text, "repository", {
    type = "string",
    default = "%s",
    description = [[
        Format string used for the repository url.
    ]],
})
entry(schema_popup_text, "documentation_label", {
    type = "string",
    default = " documentation  ",
    description = [[
        Label string used for the documentation url.
    ]],
})
entry(schema_popup_text, "documentation", {
    type = "string",
    default = "%s",
    description = [[
        Format string used for the documentation url.
    ]],
})
entry(schema_popup_text, "crates_io_label", {
    type = "string",
    default = " crates.io      ",
    description = [[
        Label string used for the crates.io url.
    ]],
})
entry(schema_popup_text, "crates_io", {
    type = "string",
    default = "%s",
    description = [[
        Format string used for the crates.io url.
    ]],
})
entry(schema_popup_text, "categories_label", {
    type = "string",
    default = " categories     ",
    description = [[
        Label string used for the categories label.
    ]],
})
entry(schema_popup_text, "keywords_label", {
    type = "string",
    default = " keywords       ",
    description = [[
        Label string used for the keywords label.
    ]],
})
-- versions
entry(schema_popup_text, "version", {
    type = "string",
    default = "  %s",
    description = [[
        Format string used for release versions.
    ]],
})
entry(schema_popup_text, "prerelease", {
    type = "string",
    default = " %s",
    description = [[
        Format string used for prerelease versions.
    ]],
})
entry(schema_popup_text, "yanked", {
    type = "string",
    default = " %s",
    description = [[
        Format string used for yanked versions.
    ]],
})
entry(schema_popup_text, "version_date", {
    type = "string",
    default = "  %s",
    description = [[
        Format string used for appending the version release date.
    ]],
})
-- features
entry(schema_popup_text, "feature", {
    type = "string",
    default = "  %s",
    description = [[
        Format string used for disabled features.
    ]],
})
entry(schema_popup_text, "enabled", {
    type = "string",
    default = " %s",
    description = [[
        Format string used for enabled features.
    ]],
})
entry(schema_popup_text, "transitive", {
    type = "string",
    default = " %s",
    description = [[
        Format string used for transitively enabled features.
    ]],
})
-- dependencies
entry(schema_popup_text, "normal_dependencies_title", {
    type = "string",
    default = " Dependencies",
    description = [[
        Format string used for the title of the normal dependencies section.
    ]],
})
entry(schema_popup_text, "build_dependencies_title", {
    type = "string",
    default = " Build dependencies",
    description = [[
        Format string used for the title of the build dependencies section.
    ]],
})
entry(schema_popup_text, "dev_dependencies_title", {
    type = "string",
    default = " Dev dependencies",
    description = [[
        Format string used for the title of the dev dependencies section.
    ]],
})
entry(schema_popup_text, "dependency", {
    type = "string",
    default = "  %s",
    description = [[
        Format string used for dependencies and their version requirement.
    ]],
})
entry(schema_popup_text, "optional", {
    type = "string",
    default = " %s",
    description = [[
        Format string used for optional dependencies and their version requirement.
    ]],
})
entry(schema_popup_text, "dependency_version", {
    type = "string",
    default = "  %s",
    description = [[
        Format string used for appending the dependency version.
    ]],
})
entry(schema_popup_text, "loading", {
    type = "string",
    default = "  ",
    description = [[
        Format string used as a loading indicator when fetching dependencies.
    ]],
})
-- deprecated
entry(schema_popup_text, "date", {
    type = "string",
    deprecated = {
        new_field = { "popup", "text", "version_date" }
    }
})


entry(schema_popup, "highlight", {
    type = "section",
    description = [[
        Highlight groups for popup elements.
    ]],
    fields = {},
})
local schema_popup_hi = schema_popup.highlight.fields
entry(schema_popup_hi, "title", {
    type = "string",
    default = "CratesNvimPopupTitle",
    description = [[
        Highlight group used for the popup title.
    ]],
})
entry(schema_popup_hi, "pill_text", {
    type = "string",
    default = "CratesNvimPopupPillText",
    description = [[
        Highlight group used for a pill's text (keywords and categories).
    ]],
})
entry(schema_popup_hi, "pill_border", {
    type = "string",
    default = "CratesNvimPopupPillBorder",
    description = [[
        Highlight group used for a pill's border (keywords and categories).
    ]],
})
-- crate
entry(schema_popup_hi, "description", {
    type = "string",
    default = "CratesNvimPopupDescription",
    description = [[
        Highlight group used for the crate description.
    ]],
})
entry(schema_popup_hi, "created_label", {
    type = "string",
    default = "CratesNvimPopupLabel",
    description = [[
        Highlight group used for the creation date label.
    ]],
})
entry(schema_popup_hi, "created", {
    type = "string",
    default = "CratesNvimPopupValue",
    description = [[
        Highlight group used for the creation date.
    ]],
})
entry(schema_popup_hi, "updated_label", {
    type = "string",
    default = "CratesNvimPopupLabel",
    description = [[
        Highlight group used for the updated date label.
    ]],
})
entry(schema_popup_hi, "updated", {
    type = "string",
    default = "CratesNvimPopupValue",
    description = [[
        Highlight group used for the updated date.
    ]],
})
entry(schema_popup_hi, "downloads_label", {
    type = "string",
    default = "CratesNvimPopupLabel",
    description = [[
        Highlight group used for the download count label.
    ]],
})
entry(schema_popup_hi, "downloads", {
    type = "string",
    default = "CratesNvimPopupValue",
    description = [[
        Highlight group used for the download count.
    ]],
})
entry(schema_popup_hi, "homepage_label", {
    type = "string",
    default = "CratesNvimPopupLabel",
    description = [[
        Highlight group used for the homepage url label.
    ]],
})
entry(schema_popup_hi, "homepage", {
    type = "string",
    default = "CratesNvimPopupUrl",
    description = [[
        Highlight group used for the homepage url.
    ]],
})
entry(schema_popup_hi, "repository_label", {
    type = "string",
    default = "CratesNvimPopupLabel",
    description = [[
        Highlight group used for the repository url label.
    ]],
})
entry(schema_popup_hi, "repository", {
    type = "string",
    default = "CratesNvimPopupUrl",
    description = [[
        Highlight group used for the repository url.
    ]],
})
entry(schema_popup_hi, "documentation_label", {
    type = "string",
    default = "CratesNvimPopupLabel",
    description = [[
        Highlight group used for the documentation url label.
    ]],
})
entry(schema_popup_hi, "documentation", {
    type = "string",
    default = "CratesNvimPopupUrl",
    description = [[
        Highlight group used for the documentation url.
    ]],
})
entry(schema_popup_hi, "crates_io_label", {
    type = "string",
    default = "CratesNvimPopupLabel",
    description = [[
        Highlight group used for the crates.io url label.
    ]],
})
entry(schema_popup_hi, "crates_io", {
    type = "string",
    default = "CratesNvimPopupUrl",
    description = [[
        Highlight group used for the crates.io url.
    ]],
})
entry(schema_popup_hi, "categories_label", {
    type = "string",
    default = "CratesNvimPopupLabel",
    description = [[
        Highlight group used for the categories label.
    ]],
})
entry(schema_popup_hi, "keywords_label", {
    type = "string",
    default = "CratesNvimPopupLabel",
    description = [[
        Highlight group used for the keywords label.
    ]],
})
-- versions
entry(schema_popup_hi, "version", {
    type = "string",
    default = "CratesNvimPopupVersion",
    description = [[
        Highlight group used for versions inside the popup.
    ]],
})
entry(schema_popup_hi, "prerelease", {
    type = "string",
    default = "CratesNvimPopupPreRelease",
    description = [[
        Highlight group used for pre-release versions inside the popup.
    ]],
})
entry(schema_popup_hi, "yanked", {
    type = "string",
    default = "CratesNvimPopupYanked",
    description = [[
        Highlight group used for yanked versions inside the popup.
    ]],
})
entry(schema_popup_hi, "version_date", {
    type = "string",
    default = "CratesNvimPopupVersionDate",
    description = [[
        Highlight group used for the version date inside the popup.
    ]],
})
-- features
entry(schema_popup_hi, "feature", {
    type = "string",
    default = "CratesNvimPopupFeature",
    description = [[
        Highlight group used for disabled features inside the popup.
    ]],
})
entry(schema_popup_hi, "enabled", {
    type = "string",
    default = "CratesNvimPopupEnabled",
    description = [[
        Highlight group used for enabled features inside the popup.
    ]],
})
entry(schema_popup_hi, "transitive", {
    type = "string",
    default = "CratesNvimPopupTransitive",
    description = [[
        Highlight group used for transitively enabled features inside the popup.
    ]],
})
-- dependencies
entry(schema_popup_hi, "normal_dependencies_title", {
    type = "string",
    default = "CratesNvimPopupNormalDependenciesTitle",
    description = [[
        Highlight group used for the title of the normal dependencies section.
    ]],
})
entry(schema_popup_hi, "build_dependencies_title", {
    type = "string",
    default = "CratesNvimPopupBuildDependenciesTitle",
    description = [[
        Highlight group used for the title of the build dependencies section.
    ]],
})
entry(schema_popup_hi, "dev_dependencies_title", {
    type = "string",
    default = "CratesNvimPopupDevDependenciesTitle",
    description = [[
        Highlight group used for the title of the dev dependencies section.
    ]],
})
entry(schema_popup_hi, "dependency", {
    type = "string",
    default = "CratesNvimPopupDependency",
    description = [[
        Highlight group used for dependencies inside the popup.
    ]],
})
entry(schema_popup_hi, "optional", {
    type = "string",
    default = "CratesNvimPopupOptional",
    description = [[
        Highlight group used for optional dependencies inside the popup.
    ]],
})
entry(schema_popup_hi, "dependency_version", {
    type = "string",
    default = "CratesNvimPopupDependencyVersion",
    description = [[
        Highlight group used for the dependency version inside the popup.
    ]],
})
entry(schema_popup_hi, "loading", {
    type = "string",
    default = "CratesNvimPopupLoading",
    description = [[
        Highlight group for the loading indicator inside the popup.
    ]],
})


entry(schema_popup, "keys", {
    type = "section",
    description = [[
        Key mappings inside the popup.
    ]],
    fields = {},
})
local schema_popup_keys = schema_popup.keys.fields
entry(schema_popup_keys, "hide", {
    type = "table",
    default = { "q", "<esc>" },
    description = [[
        Hides the popup.
    ]],
})
-- crate
entry(schema_popup_keys, "open_url", {
    type = "table",
    default = { "<cr>" },
    description = [[
        Key mappings to open the url on the current line.
    ]],
})
-- versions
entry(schema_popup_keys, "select", {
    type = "table",
    default = { "<cr>" },
    description = [[
        Key mappings to insert the version respecting the |crates-config-smart_insert| flag.
    ]],
})
entry(schema_popup_keys, "select_alt", {
    type = "table",
    default = { "s" },
    description = [[
        Key mappings to insert the version using the opposite of |crates-config-smart_insert| flag.
    ]],
})
-- features
entry(schema_popup_keys, "toggle_feature", {
    type = "table",
    default = { "<cr>" },
    description = [[
        Key mappings to enable or disable the feature on the current line inside the popup.
    ]],
})
-- common
entry(schema_popup_keys, "copy_value", {
    type = "table",
    default = { "yy" },
    description = [[
        Key mappings to copy the value on the current line inside the popup.
    ]],
})
entry(schema_popup_keys, "goto_item", {
    type = "table",
    default = { "gd", "K", "<C-LeftMouse>" },
    description = [[
        Key mappings to go to the item on the current line inside the popup.
    ]],
})
entry(schema_popup_keys, "jump_forward", {
    type = "table",
    default = { "<c-i>" },
    description = [[
        Key mappings to jump forward in the popup jump history.
    ]],
})
entry(schema_popup_keys, "jump_back", {
    type = "table",
    default = { "<c-o>", "<C-RightMouse>" },
    description = [[
        Key mappings to go back in the popup jump history.
    ]],
})
-- deprecated
entry(schema_popup_keys, "goto_feature", {
    type = "table",
    deprecated = {
        new_field = { "popup", "keys", "goto_item" },
    }
})
entry(schema_popup_keys, "jump_forward_feature", {
    type = "table",
    deprecated = {
        new_field = { "popup", "keys", "jump_forward" },
    }
})
entry(schema_popup_keys, "jump_back_feature", {
    type = "table",
    deprecated = {
        new_field = { "popup", "keys", "jump_back" },
    }
})
entry(schema_popup_keys, "copy_version", {
    type = "table",
    deprecated = {
        new_field = { "popup", "keys", "copy_value" },
    }
})


entry(M.schema, "src", {
    type = "section",
    description = [[
        Configuration options for completion sources.
    ]],
    fields = {},
})
local schema_src = M.schema.src.fields
entry(schema_src, "insert_closing_quote", {
    type = "boolean",
    default = true,
    description = [[
        Insert a closing quote on completion if there is none.
    ]],
})
entry(schema_src, "text", {
    type = "section",
    description = [[
        Text shown in the completion source documentation preview.
    ]],
    fields = {},
})
local schema_src_text = schema_src.text.fields
entry(schema_src_text, "prerelease", {
    type = "string",
    default = "  pre-release ",
    description = [[
        Text shown in the completion source documentation preview for pre-release versions.
    ]],
})
entry(schema_src_text, "yanked", {
    type = "string",
    default = "  yanked ",
    description = [[
        Text shown in the completion source documentation preview for yanked versions.
    ]],
})


entry(schema_src, "coq", {
    type = "section",
    description = [[
        Configuration options for the |coq_nvim| completion source.
    ]],
    fields = {},
})
local schema_src_coq = schema_src.coq.fields
entry(schema_src_coq, "enabled", {
    type = "boolean",
    default = false,
    description = [[
        Whether to load and register the |coq_nvim| source.
    ]],
})
entry(schema_src_coq, "name", {
    type = "string",
    default = "Crates",
    description = [[
        The source name displayed by |coq_nvim|.
    ]],
})

entry(M.schema, "null_ls", {
    type = "section",
    description = [[
        Configuration options for null-ls.nvim actions.
    ]],
    fields = {},
})
local schema_null_ls = M.schema.null_ls.fields
entry(schema_null_ls, "enabled", {
    type = "boolean",
    default = false,
    description = [[
        Whether to register the |null-ls.nvim| source.
    ]],
})
entry(schema_null_ls, "name", {
    type = "string",
    default = "Crates",
    description = [[
        The |null-ls.nvim| name.
    ]],
})

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
