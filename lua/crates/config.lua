local M = {}

---@class Config
---@field smart_insert boolean
---@field insert_closing_quote boolean
---@field autoload boolean
---@field autoupdate boolean
---@field autoupdate_throttle integer
---@field loading_indicator boolean
---@field date_format string
---@field thousands_separator string
---@field notification_title string
---@field curl_args string[]
---@field open_programs string[]
---@field max_parallel_requests integer
---@field expand_crate_moves_cursor boolean
---@field disable_invalid_feature_diagnostic boolean
---@field enable_update_available_warning boolean
---@field on_attach fun(bufnr: integer)
---@field text TextConfig
---@field highlight HighlightConfig
---@field diagnostic DiagnosticConfig
---@field popup PopupConfig
---@field src SrcConfig
---@field null_ls NullLsConfig
---@field lsp LspConfig

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

---@class DiagnosticConfig
---@field section_invalid string
---@field workspace_section_not_default string
---@field workspace_section_has_target string
---@field section_dup string
---@field section_dup_orig string
---@field crate_dup string
---@field crate_dup_orig string
---@field crate_novers string
---@field crate_error_fetching string
---@field crate_name_case string
---@field vers_upgrade string
---@field vers_pre string
---@field vers_yanked string
---@field vers_nomatch string
---@field def_invalid string
---@field feat_dup string
---@field feat_dup_orig string
---@field feat_invalid string

---@class PopupConfig
---@field autofocus boolean
---@field hide_on_select boolean
---@field copy_register string
---@field style string
---@field border string|string[]
---@field show_version_date boolean
---@field show_dependency_version boolean
---@field max_height integer
---@field min_width integer
---@field padding integer
---@field text PopupTextConfig
---@field highlight PopupHighlightConfig
---@field keys PopupKeyConfig

---@class PopupTextConfig
---@field title string
---@field pill_left string
---@field pill_right string
-- crate
---@field description string
---@field created string
---@field created_label string
---@field updated string
---@field updated_label string
---@field downloads string
---@field downloads_label string
---@field homepage string
---@field homepage_label string
---@field repository string
---@field repository_label string
---@field documentation string
---@field documentation_label string
---@field crates_io string
---@field crates_io_label string
---@field categories_label string
---@field keywords_label string
-- version
---@field version string
---@field prerelease string
---@field yanked string
---@field version_date string
-- feature
---@field feature string
---@field enabled string
---@field transitive string
-- dependencies
---@field normal_dependencies_title string
---@field build_dependencies_title string
---@field dev_dependencies_title string
---@field dependency string
---@field optional string
---@field dependency_version string
---@field loading string

---@class PopupHighlightConfig
---@field title string
---@field pill_text string
---@field pill_border string
-- crate
---@field created string
---@field created_label string
---@field updated string
---@field updated_label string
---@field description string
---@field downloads string
---@field downloads_label string
---@field homepage string
---@field homepage_label string
---@field repository string
---@field repository_label string
---@field documentation string
---@field documentation_label string
---@field crates_io string
---@field crates_io_label string
---@field categories_label string
---@field keywords_label string
-- version
---@field version string
---@field prerelease string
---@field yanked string
---@field version_date string
-- feature
---@field feature string
---@field enabled string
---@field transitive string
-- dependencies
---@field normal_dependencies_title string
---@field build_dependencies_title string
---@field dev_dependencies_title string
---@field dependency string
---@field optional string
---@field dependency_version string
---@field loading string

---@class PopupKeyConfig
---@field hide string[]
---@field open_url string[]
---@field select string[]
---@field select_alt string[]
---@field toggle_feature string[]
---@field copy_value string[]
---@field goto_item string[]
---@field jump_forward string[]
---@field jump_back string[]

---@class SrcConfig
---@field insert_closing_quote boolean
---@field text SrcTextConfig
---@field coq CoqConfig
---@field cmp CmpConfig

---@class SrcTextConfig
---@field prerelease string
---@field yanked string

---@class CoqConfig
---@field enabled boolean
---@field name string

---@class CmpConfig
---@field enabled boolean
---@field use_custom_kind boolean
---@field kind_text CmpKindTextConfig
---@field kind_highlight CmpKindHighlightConfig

---@class CmpKindTextConfig
---@field version string
---@field feature string

---@class CmpKindHighlightConfig
---@field version string
---@field feature string

---@class NullLsConfig
---@field enabled boolean
---@field name string

---@class LspConfig
---@field enabled boolean
---@field name string
---@field on_attach fun(client: lsp.Client, bufnr: integer)
---@field actions boolean
---@field completion boolean

---@enum SchemaType
local SchemaType = {
    -- A record of grouped options
    section = "section",
    -- The rest are lua types checked at runtime
    table = "table",
    string = "string",
    number = "number",
    boolean = "boolean",
    fun = "function",
}

---@alias SchemaElement
---| SectionSchemaElement
---| HiddenSectionSchemaElement
---| FieldSchemaElement
---| HiddenFieldSchemaElement
---| DeprecatedSchemaElement

---@class SectionSchemaElement
---@field name string
---@field type SchemaType|SchemaType[]
---@field description string
---@field fields table<string|integer,SchemaElement>

---@class HiddenSectionSchemaElement
---@field name string
---@field type SchemaType|SchemaType[]
---@field fields table<string|integer,SchemaElement>
---@field hidden boolean

---@class FieldSchemaElement
---@field name string
---@field type SchemaType|SchemaType[]
---@field default any
---@field default_text string|nil
---@field description string

---@class HiddenFieldSchemaElement
---@field name string
---@field type SchemaType|SchemaType[]
---@field default any
---@field hidden boolean

---@class DeprecatedSchemaElement
---@field name string
---@field type SchemaType|SchemaType[]
---@field deprecated Deprecated|nil

---@class Deprecated
---@field new_field string[]|nil
---@field hard boolean|nil

---@param schema table<string|integer,SchemaElement>
---@param elem SchemaElement
local function entry(schema, elem)
    table.insert(schema, elem)
    schema[elem.name] = elem
end

---@param schema table<string|integer,SchemaElement>
---@param elem SectionSchemaElement|HiddenSectionSchemaElement
---@return table<string|integer,SchemaElement>
local function section_entry(schema, elem)
    table.insert(schema, elem)
    schema[elem.name] = elem
    return elem.fields
end

M.schema = {}
entry(M.schema, {
    name = "smart_insert",
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
entry(M.schema, {
    name = "insert_closing_quote",
    type = "boolean",
    default = true,
    description = [[
        Insert a closing quote when updating or upgrading a version, if there is none.
    ]],
})
entry(M.schema, {
    name = "autoload",
    type = "boolean",
    default = true,
    description = [[
        Automatically run update when opening a Cargo.toml.
    ]],
})
entry(M.schema, {
    name = "autoupdate",
    type = "boolean",
    default = true,
    description = [[
        Automatically update when editing text.
    ]],
})
entry(M.schema, {
    name = "autoupdate_throttle",
    type = "number",
    default = 250,
    description = [[
        Rate limit the auto update in milliseconds
    ]],
})
entry(M.schema, {
    name = "loading_indicator",
    type = "boolean",
    default = true,
    description = [[
        Show a loading indicator while fetching crate versions.
    ]],
})
entry(M.schema, {
    name = "date_format",
    type = "string",
    default = "%Y-%m-%d",
    description = [[
        The date format passed to `os.date`.
    ]],
})
entry(M.schema, {
    name = "thousands_separator",
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
entry(M.schema, {
    name = "notification_title",
    type = "string",
    default = "crates.nvim",
    description = [[
        The title displayed in notifications.
    ]],
})
entry(M.schema, {
    name = "curl_args",
    type = "table",
    default = { "-sL", "--retry", "1" },
    description = [[
        A list of arguments passed to curl when fetching metadata from crates.io.
    ]],
})
entry(M.schema, {
    name = "max_parallel_requests",
    type = "number",
    default = 80,
    description = [[
        Maximum number of parallel requests.
    ]],
})
entry(M.schema, {
    name = "expand_crate_moves_cursor",
    type = "boolean",
    default = true,
    description = [[
        Whether to move the cursor on |crates.expand_plain_crate_to_inline_table()|.
    ]],
})
entry(M.schema, {
    name = "open_programs",
    type = "table",
    default = { "xdg-open", "open" },
    description = [[
        A list of programs that used to open urls.
    ]],
})
-- TODO: Blocked on: https://github.com/rust-lang/crates.io/issues/1539
entry(M.schema, {
    name = "disable_invalid_feature_diagnostic",
    type = "boolean",
    default = false,
    description = [[
        This is a temporary solution for:
        https://github.com/Saecki/crates.nvim/issues/14
    ]],
})
entry(M.schema, {
    name = "enable_update_available_warning",
    type = "boolean",
    default = true,
    description = [[
        Enable warnings for outdated crates.
    ]],
})
entry(M.schema, {
    name = "on_attach",
    type = "function",
    default = function(_) end,
    default_text = "function(bufnr) end",
    description = [[
        Callback to run when a `Cargo.toml` file is opened.

        NOTE: Ignored if |crates-config-autoload| is disabled.
    ]],
})
-- deprecated
entry(M.schema, {
    name = "avoid_prerelease",
    type = "boolean",
    deprecated = {
        hard = true,
    },
})

entry(M.schema, {
    name = "text",
    type = "section",
    description = [[
        Strings used to format virtual text.
    ]],
    fields = {},
})
---@type table<string|integer,SchemaElement>
local schema_text = M.schema.text.fields
entry(schema_text, {
    name = "loading",
    type = "string",
    default = "   Loading",
    description = [[
        Format string used while loading crate information.
    ]],
})
entry(schema_text, {
    name = "version",
    type = "string",
    default = "   %s",
    description = [[
        format string used for the latest compatible version
    ]],
})
entry(schema_text, {
    name = "prerelease",
    type = "string",
    default = "   %s",
    description = [[
        Format string used for pre-release versions.
    ]],
})
entry(schema_text, {
    name = "yanked",
    type = "string",
    default = "   %s",
    description = [[
        Format string used for yanked versions.
    ]],
})
entry(schema_text, {
    name = "nomatch",
    type = "string",
    default = "   No match",
    description = [[
        Format string used when there is no matching version.
    ]],
})
entry(schema_text, {
    name = "upgrade",
    type = "string",
    default = "   %s",
    description = [[
        Format string used when there is an upgrade candidate.
    ]],
})
entry(schema_text, {
    name = "error",
    type = "string",
    default = "   Error fetching crate",
    description = [[
        Format string used when there was an error loading crate information.
    ]],
})


entry(M.schema, {
    name = "highlight",
    type = "section",
    description = [[
        Highlight groups used for virtual text.
    ]],
    fields = {},
})
---@type table<string|integer,SchemaElement>
local schema_hi = M.schema.highlight.fields
entry(schema_hi, {
    name = "loading",
    type = "string",
    default = "CratesNvimLoading",
    description = [[
        Highlight group used while loading crate information.
    ]],
})
entry(schema_hi, {
    name = "version",
    type = "string",
    default = "CratesNvimVersion",
    description = [[
        Highlight group used for the latest compatible version.
    ]],
})
entry(schema_hi, {
    name = "prerelease",
    type = "string",
    default = "CratesNvimPreRelease",
    description = [[
        Highlight group used for pre-release versions.
    ]],
})
entry(schema_hi, {
    name = "yanked",
    type = "string",
    default = "CratesNvimYanked",
    description = [[
        Highlight group used for yanked versions.
    ]],
})
entry(schema_hi, {
    name = "nomatch",
    type = "string",
    default = "CratesNvimNoMatch",
    description = [[
        Highlight group used when there is no matching version.
    ]],
})
entry(schema_hi, {
    name = "upgrade",
    type = "string",
    default = "CratesNvimUpgrade",
    description = [[
        Highlight group used when there is an upgrade candidate.
    ]],
})
entry(schema_hi, {
    name = "error",
    type = "string",
    default = "CratesNvimError",
    description = [[
        Highlight group used when there was an error loading crate information.
    ]],
})


local schema_diagnostic = section_entry(M.schema, {
    name = "diagnostic",
    type = "section",
    fields = {},
    hidden = true,
})
entry(schema_diagnostic, {
    name = "section_invalid",
    type = "string",
    default = "Invalid dependency section",
    hidden = true,
})
entry(schema_diagnostic, {
    name = "workspace_section_not_default",
    type = "string",
    default = "Workspace dependency sections don't support other kinds of dependencies like build or dev",
    hidden = true,
})
entry(schema_diagnostic, {
    name = "workspace_section_has_target",
    type = "string",
    default = "Workspace dependency sections don't support target specifiers",
    hidden = true,
})
entry(schema_diagnostic, {
    name = "section_dup",
    type = "string",
    default = "Duplicate dependency section",
    hidden = true,
})
entry(schema_diagnostic, {
    name = "section_dup_orig",
    type = "string",
    default = "Original dependency section is defined here",
    hidden = true,
})
entry(schema_diagnostic, {
    name = "crate_dup",
    type = "string",
    default = "Duplicate crate entry",
    hidden = true,
})
entry(schema_diagnostic, {
    name = "crate_dup_orig",
    type = "string",
    default = "Original crate entry is defined here",
    hidden = true,
})
entry(schema_diagnostic, {
    name = "crate_novers",
    type = "string",
    default = "Missing version requirement",
    hidden = true,
})
entry(schema_diagnostic, {
    name = "crate_error_fetching",
    type = "string",
    default = "Error fetching crate",
    hidden = true,
})
entry(schema_diagnostic, {
    name = "crate_name_case",
    type = "string",
    default = "Incorrect crate name casing",
    hidden = true,
})
entry(schema_diagnostic, {
    name = "vers_upgrade",
    type = "string",
    default = "There is an upgrade available",
    hidden = true,
})
entry(schema_diagnostic, {
    name = "vers_pre",
    type = "string",
    default = "Requirement only matches a pre-release version\nIf you want to use the pre-release package, it needs to be specified explicitly",
    hidden = true,
})
entry(schema_diagnostic, {
    name = "vers_yanked",
    type = "string",
    default = "Requirement only matches a yanked version",
    hidden = true,
})
entry(schema_diagnostic, {
    name = "vers_nomatch",
    type = "string",
    default = "Requirement doesn't match a version",
    hidden = true,
})
entry(schema_diagnostic, {
    name = "def_invalid",
    type = "string",
    default = "Invalid boolean value",
    hidden = true,
})
entry(schema_diagnostic, {
    name = "feat_dup",
    type = "string",
    default = "Duplicate feature entry",
    hidden = true,
})
entry(schema_diagnostic, {
    name = "feat_dup_orig",
    type = "string",
    default = "Original feature entry is defined here",
    hidden = true,
})
entry(schema_diagnostic, {
    name = "feat_invalid",
    type = "string",
    default = "Invalid feature",
    hidden = true,
})


local schema_popup = section_entry(M.schema, {
    name = "popup",
    type = "section",
    description = [[
        Popup configuration.
    ]],
    fields = {},
})
entry(schema_popup, {
    name = "autofocus",
    type = "boolean",
    default = false,
    description = [[
        Focus the versions popup when opening it.
    ]],
})
entry(schema_popup, {
    name = "hide_on_select",
    type = "boolean",
    default = false,
    description = [[
        Hides the popup after selecting a version.
    ]],
})
entry(schema_popup, {
    name = "copy_register",
    type = "string",
    default = '"',
    description = [[
        The register into which the version will be copied.
    ]],
})
entry(schema_popup, {
    name = "style",
    type = "string",
    default = "minimal",
    description = [[
        Same as nvim_open_win config.style.
    ]],
})
entry(schema_popup, {
    name = "border",
    type = { "string", "table" },
    default = "none",
    description = [[
        Same as nvim_open_win config.border.
    ]],
})
entry(schema_popup, {
    name = "show_version_date",
    type = "boolean",
    default = false,
    description = [[
        Display when a version was released.
    ]],
})
entry(schema_popup, {
    name = "show_dependency_version",
    type = "boolean",
    default = true,
    description = [[
        Display when a version was released.
    ]],
})
entry(schema_popup, {
    name = "max_height",
    type = "number",
    default = 30,
    description = [[
        The maximum height of the popup.
    ]],
})
entry(schema_popup, {
    name = "min_width",
    type = "number",
    default = 20,
    description = [[
        The minimum width of the popup.
    ]],
})
entry(schema_popup, {
    name = "padding",
    type = "number",
    default = 1,
    description = [[
        The horizontal padding of the popup.
    ]],
})
-- deprecated
entry(schema_popup, {
    name = "version_date",
    type = "boolean",
    deprecated = {
        new_field = { "popup", "show_version_date" },
        hard = true,
    }
})


entry(schema_popup, {
    name = "text",
    type = "section",
    description = [[
        Strings used to format the text inside the popup.
    ]],
    fields = {},
})
local schema_popup_text = schema_popup.text.fields
entry(schema_popup_text, {
    name = "title",
    type = "string",
    default = " %s",
    description = [[
        Format string used for the popup title.
    ]],
})
entry(schema_popup_text, {
    name = "pill_left",
    type = "string",
    default = "",
    description = [[
        Left border of a pill (keywords and categories).
    ]],
})
entry(schema_popup_text, {
    name = "pill_right",
    type = "string",
    default = "",
    description = [[
        Right border of a pill (keywords and categories).
    ]],
})
-- crate
entry(schema_popup_text, {
    name = "description",
    type = "string",
    default = "%s",
    description = [[
        Format string used for the description.
    ]],
})
entry(schema_popup_text, {
    name = "created_label",
    type = "string",
    default = " created        ",
    description = [[
        Label string used for the creation date.
    ]],
})
entry(schema_popup_text, {
    name = "created",
    type = "string",
    default = "%s",
    description = [[
        Format string used for the creation date.
    ]],
})
entry(schema_popup_text, {
    name = "updated_label",
    type = "string",
    default = " updated        ",
    description = [[
        Label string used for the updated date.
    ]],
})
entry(schema_popup_text, {
    name = "updated",
    type = "string",
    default = "%s",
    description = [[
        Format string used for the updated date.
    ]],
})
entry(schema_popup_text, {
    name = "downloads_label",
    type = "string",
    default = " downloads      ",
    description = [[
        Label string used for the download count.
    ]],
})
entry(schema_popup_text, {
    name = "downloads",
    type = "string",
    default = "%s",
    description = [[
        Format string used for the download count.
    ]],
})
entry(schema_popup_text, {
    name = "homepage_label",
    type = "string",
    default = " homepage       ",
    description = [[
        Label string used for the homepage url.
    ]],
})
entry(schema_popup_text, {
    name = "homepage",
    type = "string",
    default = "%s",
    description = [[
        Format string used for the homepage url.
    ]],
})
entry(schema_popup_text, {
    name = "repository_label",
    type = "string",
    default = " repository     ",
    description = [[
        Label string used for the repository url.
    ]],
})
entry(schema_popup_text, {
    name = "repository",
    type = "string",
    default = "%s",
    description = [[
        Format string used for the repository url.
    ]],
})
entry(schema_popup_text, {
    name = "documentation_label",
    type = "string",
    default = " documentation  ",
    description = [[
        Label string used for the documentation url.
    ]],
})
entry(schema_popup_text, {
    name = "documentation",
    type = "string",
    default = "%s",
    description = [[
        Format string used for the documentation url.
    ]],
})
entry(schema_popup_text, {
    name = "crates_io_label",
    type = "string",
    default = " crates.io      ",
    description = [[
        Label string used for the crates.io url.
    ]],
})
entry(schema_popup_text, {
    name = "crates_io",
    type = "string",
    default = "%s",
    description = [[
        Format string used for the crates.io url.
    ]],
})
entry(schema_popup_text, {
    name = "categories_label",
    type = "string",
    default = " categories     ",
    description = [[
        Label string used for the categories label.
    ]],
})
entry(schema_popup_text, {
    name = "keywords_label",
    type = "string",
    default = " keywords       ",
    description = [[
        Label string used for the keywords label.
    ]],
})
-- versions
entry(schema_popup_text, {
    name = "version",
    type = "string",
    default = "  %s",
    description = [[
        Format string used for release versions.
    ]],
})
entry(schema_popup_text, {
    name = "prerelease",
    type = "string",
    default = " %s",
    description = [[
        Format string used for prerelease versions.
    ]],
})
entry(schema_popup_text, {
    name = "yanked",
    type = "string",
    default = " %s",
    description = [[
        Format string used for yanked versions.
    ]],
})
entry(schema_popup_text, {
    name = "version_date",
    type = "string",
    default = "  %s",
    description = [[
        Format string used for appending the version release date.
    ]],
})
-- features
entry(schema_popup_text, {
    name = "feature",
    type = "string",
    default = "  %s",
    description = [[
        Format string used for disabled features.
    ]],
})
entry(schema_popup_text, {
    name = "enabled",
    type = "string",
    default = " %s",
    description = [[
        Format string used for enabled features.
    ]],
})
entry(schema_popup_text, {
    name = "transitive",
    type = "string",
    default = " %s",
    description = [[
        Format string used for transitively enabled features.
    ]],
})
-- dependencies
entry(schema_popup_text, {
    name = "normal_dependencies_title",
    type = "string",
    default = " Dependencies",
    description = [[
        Format string used for the title of the normal dependencies section.
    ]],
})
entry(schema_popup_text, {
    name = "build_dependencies_title",
    type = "string",
    default = " Build dependencies",
    description = [[
        Format string used for the title of the build dependencies section.
    ]],
})
entry(schema_popup_text, {
    name = "dev_dependencies_title",
    type = "string",
    default = " Dev dependencies",
    description = [[
        Format string used for the title of the dev dependencies section.
    ]],
})
entry(schema_popup_text, {
    name = "dependency",
    type = "string",
    default = "  %s",
    description = [[
        Format string used for dependencies and their version requirement.
    ]],
})
entry(schema_popup_text, {
    name = "optional",
    type = "string",
    default = " %s",
    description = [[
        Format string used for optional dependencies and their version requirement.
    ]],
})
entry(schema_popup_text, {
    name = "dependency_version",
    type = "string",
    default = "  %s",
    description = [[
        Format string used for appending the dependency version.
    ]],
})
entry(schema_popup_text, {
    name = "loading",
    type = "string",
    default = "  ",
    description = [[
        Format string used as a loading indicator when fetching dependencies.
    ]],
})
-- deprecated
entry(schema_popup_text, {
    name = "date",
    type = "string",
    deprecated = {
        new_field = { "popup", "text", "version_date" },
        hard = true,
    }
})


entry(schema_popup, {
    name = "highlight",
    type = "section",
    description = [[
        Highlight groups for popup elements.
    ]],
    fields = {},
})
local schema_popup_hi = schema_popup.highlight.fields
entry(schema_popup_hi, {
    name = "title",
    type = "string",
    default = "CratesNvimPopupTitle",
    description = [[
        Highlight group used for the popup title.
    ]],
})
entry(schema_popup_hi, {
    name = "pill_text",
    type = "string",
    default = "CratesNvimPopupPillText",
    description = [[
        Highlight group used for a pill's text (keywords and categories).
    ]],
})
entry(schema_popup_hi, {
    name = "pill_border",
    type = "string",
    default = "CratesNvimPopupPillBorder",
    description = [[
        Highlight group used for a pill's border (keywords and categories).
    ]],
})
-- crate
entry(schema_popup_hi, {
    name = "description",
    type = "string",
    default = "CratesNvimPopupDescription",
    description = [[
        Highlight group used for the crate description.
    ]],
})
entry(schema_popup_hi, {
    name = "created_label",
    type = "string",
    default = "CratesNvimPopupLabel",
    description = [[
        Highlight group used for the creation date label.
    ]],
})
entry(schema_popup_hi, {
    name = "created",
    type = "string",
    default = "CratesNvimPopupValue",
    description = [[
        Highlight group used for the creation date.
    ]],
})
entry(schema_popup_hi, {
    name = "updated_label",
    type = "string",
    default = "CratesNvimPopupLabel",
    description = [[
        Highlight group used for the updated date label.
    ]],
})
entry(schema_popup_hi, {
    name = "updated",
    type = "string",
    default = "CratesNvimPopupValue",
    description = [[
        Highlight group used for the updated date.
    ]],
})
entry(schema_popup_hi, {
    name = "downloads_label",
    type = "string",
    default = "CratesNvimPopupLabel",
    description = [[
        Highlight group used for the download count label.
    ]],
})
entry(schema_popup_hi, {
    name = "downloads",
    type = "string",
    default = "CratesNvimPopupValue",
    description = [[
        Highlight group used for the download count.
    ]],
})
entry(schema_popup_hi, {
    name = "homepage_label",
    type = "string",
    default = "CratesNvimPopupLabel",
    description = [[
        Highlight group used for the homepage url label.
    ]],
})
entry(schema_popup_hi, {
    name = "homepage",
    type = "string",
    default = "CratesNvimPopupUrl",
    description = [[
        Highlight group used for the homepage url.
    ]],
})
entry(schema_popup_hi, {
    name = "repository_label",
    type = "string",
    default = "CratesNvimPopupLabel",
    description = [[
        Highlight group used for the repository url label.
    ]],
})
entry(schema_popup_hi, {
    name = "repository",
    type = "string",
    default = "CratesNvimPopupUrl",
    description = [[
        Highlight group used for the repository url.
    ]],
})
entry(schema_popup_hi, {
    name = "documentation_label",
    type = "string",
    default = "CratesNvimPopupLabel",
    description = [[
        Highlight group used for the documentation url label.
    ]],
})
entry(schema_popup_hi, {
    name = "documentation",
    type = "string",
    default = "CratesNvimPopupUrl",
    description = [[
        Highlight group used for the documentation url.
    ]],
})
entry(schema_popup_hi, {
    name = "crates_io_label",
    type = "string",
    default = "CratesNvimPopupLabel",
    description = [[
        Highlight group used for the crates.io url label.
    ]],
})
entry(schema_popup_hi, {
    name = "crates_io",
    type = "string",
    default = "CratesNvimPopupUrl",
    description = [[
        Highlight group used for the crates.io url.
    ]],
})
entry(schema_popup_hi, {
    name = "categories_label",
    type = "string",
    default = "CratesNvimPopupLabel",
    description = [[
        Highlight group used for the categories label.
    ]],
})
entry(schema_popup_hi, {
    name = "keywords_label",
    type = "string",
    default = "CratesNvimPopupLabel",
    description = [[
        Highlight group used for the keywords label.
    ]],
})
-- versions
entry(schema_popup_hi, {
    name = "version",
    type = "string",
    default = "CratesNvimPopupVersion",
    description = [[
        Highlight group used for versions inside the popup.
    ]],
})
entry(schema_popup_hi, {
    name = "prerelease",
    type = "string",
    default = "CratesNvimPopupPreRelease",
    description = [[
        Highlight group used for pre-release versions inside the popup.
    ]],
})
entry(schema_popup_hi, {
    name = "yanked",
    type = "string",
    default = "CratesNvimPopupYanked",
    description = [[
        Highlight group used for yanked versions inside the popup.
    ]],
})
entry(schema_popup_hi, {
    name = "version_date",
    type = "string",
    default = "CratesNvimPopupVersionDate",
    description = [[
        Highlight group used for the version date inside the popup.
    ]],
})
-- features
entry(schema_popup_hi, {
    name = "feature",
    type = "string",
    default = "CratesNvimPopupFeature",
    description = [[
        Highlight group used for disabled features inside the popup.
    ]],
})
entry(schema_popup_hi, {
    name = "enabled",
    type = "string",
    default = "CratesNvimPopupEnabled",
    description = [[
        Highlight group used for enabled features inside the popup.
    ]],
})
entry(schema_popup_hi, {
    name = "transitive",
    type = "string",
    default = "CratesNvimPopupTransitive",
    description = [[
        Highlight group used for transitively enabled features inside the popup.
    ]],
})
-- dependencies
entry(schema_popup_hi, {
    name = "normal_dependencies_title",
    type = "string",
    default = "CratesNvimPopupNormalDependenciesTitle",
    description = [[
        Highlight group used for the title of the normal dependencies section.
    ]],
})
entry(schema_popup_hi, {
    name = "build_dependencies_title",
    type = "string",
    default = "CratesNvimPopupBuildDependenciesTitle",
    description = [[
        Highlight group used for the title of the build dependencies section.
    ]],
})
entry(schema_popup_hi, {
    name = "dev_dependencies_title",
    type = "string",
    default = "CratesNvimPopupDevDependenciesTitle",
    description = [[
        Highlight group used for the title of the dev dependencies section.
    ]],
})
entry(schema_popup_hi, {
    name = "dependency",
    type = "string",
    default = "CratesNvimPopupDependency",
    description = [[
        Highlight group used for dependencies inside the popup.
    ]],
})
entry(schema_popup_hi, {
    name = "optional",
    type = "string",
    default = "CratesNvimPopupOptional",
    description = [[
        Highlight group used for optional dependencies inside the popup.
    ]],
})
entry(schema_popup_hi, {
    name = "dependency_version",
    type = "string",
    default = "CratesNvimPopupDependencyVersion",
    description = [[
        Highlight group used for the dependency version inside the popup.
    ]],
})
entry(schema_popup_hi, {
    name = "loading",
    type = "string",
    default = "CratesNvimPopupLoading",
    description = [[
        Highlight group for the loading indicator inside the popup.
    ]],
})


entry(schema_popup, {
    name = "keys",
    type = "section",
    description = [[
        Key mappings inside the popup.
    ]],
    fields = {},
})
local schema_popup_keys = schema_popup.keys.fields
entry(schema_popup_keys, {
    name = "hide",
    type = "table",
    default = { "q", "<esc>" },
    description = [[
        Hides the popup.
    ]],
})
-- crate
entry(schema_popup_keys, {
    name = "open_url",
    type = "table",
    default = { "<cr>" },
    description = [[
        Key mappings to open the url on the current line.
    ]],
})
-- versions
entry(schema_popup_keys, {
    name = "select",
    type = "table",
    default = { "<cr>" },
    description = [[
        Key mappings to insert the version respecting the |crates-config-smart_insert| flag.
    ]],
})
entry(schema_popup_keys, {
    name = "select_alt",
    type = "table",
    default = { "s" },
    description = [[
        Key mappings to insert the version using the opposite of |crates-config-smart_insert| flag.
    ]],
})
-- features
entry(schema_popup_keys, {
    name = "toggle_feature",
    type = "table",
    default = { "<cr>" },
    description = [[
        Key mappings to enable or disable the feature on the current line inside the popup.
    ]],
})
-- common
entry(schema_popup_keys, {
    name = "copy_value",
    type = "table",
    default = { "yy" },
    description = [[
        Key mappings to copy the value on the current line inside the popup.
    ]],
})
entry(schema_popup_keys, {
    name = "goto_item",
    type = "table",
    default = { "gd", "K", "<C-LeftMouse>" },
    description = [[
        Key mappings to go to the item on the current line inside the popup.
    ]],
})
entry(schema_popup_keys, {
    name = "jump_forward",
    type = "table",
    default = { "<c-i>" },
    description = [[
        Key mappings to jump forward in the popup jump history.
    ]],
})
entry(schema_popup_keys, {
    name = "jump_back",
    type = "table",
    default = { "<c-o>", "<C-RightMouse>" },
    description = [[
        Key mappings to go back in the popup jump history.
    ]],
})
-- deprecated
entry(schema_popup_keys, {
    name = "goto_feature",
    type = "table",
    deprecated = {
        new_field = { "popup", "keys", "goto_item" },
        hard = true,
    }
})
entry(schema_popup_keys, {
    name = "jump_forward_feature",
    type = "table",
    deprecated = {
        new_field = { "popup", "keys", "jump_forward" },
        hard = true,
    }
})
entry(schema_popup_keys, {
    name = "jump_back_feature",
    type = "table",
    deprecated = {
        new_field = { "popup", "keys", "jump_back" },
        hard = true,
    }
})
entry(schema_popup_keys, {
    name = "copy_version",
    type = "table",
    deprecated = {
        new_field = { "popup", "keys", "copy_value" },
        hard = true,
    }
})


local schema_src = section_entry(M.schema, {
    name = "src",
    type = "section",
    description = [[
        Configuration options for completion sources.
    ]],
    fields = {},
})
entry(schema_src, {
    name = "insert_closing_quote",
    type = "boolean",
    default = true,
    description = [[
        Insert a closing quote on completion if there is none.
    ]],
})
entry(schema_src, {
    name = "text",
    type = "section",
    description = [[
        Text shown in the completion source documentation preview.
    ]],
    fields = {},
})
local schema_src_text = schema_src.text.fields
entry(schema_src_text, {
    name = "prerelease",
    type = "string",
    default = "  pre-release ",
    description = [[
        Text shown in the completion source documentation preview for pre-release versions.
    ]],
})
entry(schema_src_text, {
    name = "yanked",
    type = "string",
    default = "  yanked ",
    description = [[
        Text shown in the completion source documentation preview for yanked versions.
    ]],
})

entry(schema_src, {
    name = "cmp",
    type = "section",
    description = [[
        Configuration options for the |nvim-cmp| completion source.
    ]],
    fields = {},
})
local schema_src_cmp = schema_src.cmp.fields
entry(schema_src_cmp, {
    name = "enabled",
    type = "boolean",
    default = false,
    description = [[
        Whether to load and register the |nvim-cmp| source.

        NOTE: Ignored if |crates-config-autoload| is disabled.
        You may manually register it, after |nvim-cmp| has been loaded.
        >
            require("crates.src.cmp").setup()
        <
    ]],
})
entry(schema_src_cmp, {
    name = "use_custom_kind",
    type = "boolean",
    default = true,
    description = [[
        Use custom a custom kind to display inside the |nvim-cmp| completion menu.
    ]],
})

entry(schema_src_cmp, {
    name = "kind_text",
    type = "section",
    description = [[
        The kind text shown in the |nvim-cmp| completion menu.
    ]],
    fields = {},
})
local schema_src_cmp_kind_text = schema_src_cmp.kind_text.fields
entry(schema_src_cmp_kind_text, {
    name = "version",
    type = "string",
    default = "Version",
    description = [[
        The version kind text shown in the |nvim-cmp| completion menu.
    ]],
})
entry(schema_src_cmp_kind_text, {
    name = "feature",
    type = "string",
    default = "Feature",
    description = [[
        The feature kind text shown in the |nvim-cmp| completion menu.
    ]],
})

entry(schema_src_cmp, {
    name = "kind_highlight",
    type = "section",
    description = [[
        Highlight groups used for the kind text in the |nvim-cmp| completion menu.
    ]],
    fields = {},
})
local schema_src_cmp_kind_hi = schema_src_cmp.kind_highlight.fields
entry(schema_src_cmp_kind_hi, {
    name = "version",
    type = "string",
    default = "CmpItemKindVersion",
    description = [[
        Highlight group used for the version kind text in the |nvim-cmp| completion menu.
    ]],
})
entry(schema_src_cmp_kind_hi, {
    name = "feature",
    type = "string",
    default = "CmpItemKindFeature",
    description = [[
        Highlight group used for the feature kind text in the |nvim-cmp| completion menu.
    ]],
})

entry(schema_src, {
    name = "coq",
    type = "section",
    description = [[
        Configuration options for the |coq_nvim| completion source.
    ]],
    fields = {},
})
local schema_src_coq = schema_src.coq.fields
entry(schema_src_coq, {
    name = "enabled",
    type = "boolean",
    default = false,
    description = [[
        Whether to load and register the |coq_nvim| source.
    ]],
})
entry(schema_src_coq, {
    name = "name",
    type = "string",
    default = "crates.nvim",
    description = [[
        The source name displayed by |coq_nvim|.
    ]],
})


local schema_null_ls = section_entry(M.schema, {
    name = "null_ls",
    type = "section",
    description = [[
        Configuration options for null-ls.nvim actions.
    ]],
    fields = {},
})
entry(schema_null_ls, {
    name = "enabled",
    type = "boolean",
    default = false,
    description = [[
        Whether to register the |null-ls.nvim| source.
    ]],
})
entry(schema_null_ls, {
    name = "name",
    type = "string",
    default = "crates.nvim",
    description = [[
        The |null-ls.nvim| name.
    ]],
})


local schema_lsp = section_entry(M.schema, {
    name = "lsp",
    type = "section",
    description = [[
        Configuration options for the in-process language server.
    ]],
    fields = {},
})
entry(schema_lsp, {
    name = "enabled",
    type = "boolean",
    default = false,
    description = [[
        Whether to enable the in-process language server.
    ]],
})
entry(schema_lsp, {
    name = "name",
    type = "string",
    default = "crates.nvim",
    description = [[
        The lsp server name.
    ]],
})
entry(schema_lsp, {
    name = "on_attach",
    type = "function",
    default = function(_client, _bufnr) end,
    default_text = "function(client, bufnr) end",
    description = [[
        Callback to run when the in-process language server attaches to a buffer.

        NOTE: Ignored if |crates-config-autoload| is disabled.
    ]],
})
entry(schema_lsp, {
    name = "actions",
    type = "boolean",
    default = false,
    description = [[
        Whether to enable the `codeActionProvider` capability.
    ]],
})
entry(schema_lsp, {
    name = "completion",
    type = "boolean",
    default = false,
    description = [[
        Whether to enable the `completionProvider` capability.
    ]],
})

---@param s string
---@param ... any
local function warn(s, ...)
    vim.notify(s:format(...), vim.log.levels.WARN, { title = "crates.nvim" })
end

---@param path string[]
---@param component string
---@return string[]
local function join_path(path, component)
    ---@type string[]
    local p = {}
    for i,c in ipairs(path) do
        p[i] = c
    end
    table.insert(p, component)
    return p
end

---@param t table<string,any>
---@param path string[]
---@param value any
local function table_set_path(t, path, value)
    ---@type table<string,any>
    local current = t
    for i,c in ipairs(path) do
        if i == #path then
            current[c] = value
        elseif type(current[c]) == "table" then
            ---@type table<string,any>
            current = current[c]
        elseif current[c] == nil then
            current[c] = {}
            current = current[c]
        else
            break -- don't overwrite existing value
        end
    end
end

---comment
---@param path string[]
---@param schema table<string,SchemaElement>
---@param root_config table<string,any>
---@param user_config table<string,any>
local function handle_deprecated(path, schema, root_config, user_config)
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
                ---@cast elem SectionSchemaElement|HiddenSectionSchemaElement
                ---@cast v table<string,any>
                handle_deprecated(p, elem.fields, root_config, v)
            end
        end
    end
end

---@param path string[]
---@param schema table<string,SchemaElement>
---@param user_config table<string,any>
local function validate_schema(path, schema, user_config)
    for k,v in pairs(user_config) do
        local p = join_path(path, k)
        local elem = schema[k]

        if elem then
            local value_type = type(v)
            local dep = elem.deprecated

            if dep then
                if dep.new_field then
                    ---@type string
                    local dep_text
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
                    ---@cast elem SectionSchemaElement|HiddenSectionSchemaElement
                    validate_schema(p, elem.fields, v)
                else
                    warn(
                        "Config field '%s' was expected to be of type 'table' but was '%s', using default value.",
                        table.concat(p, "."),
                        value_type
                    )
                end
            else
                ---@type SchemaType[]
                local elem_types
                if type(elem.type) == "string" then
                    elem_types = { elem.type }
                else
                    ---@type SchemaType[]
                    elem_types = elem.type
                end

                if not vim.tbl_contains(elem_types, value_type) then
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

---@param schema table<string,SchemaElement>
---@param user_config table<string,any>
---@return table
local function build_config(schema, user_config)
    ---@type table<string,any>
    local config = {}

    for k,elem in pairs(schema) do
        local v = user_config[k]
        local value_type = type(v)

        if elem.type == "section" then
            ---@cast elem SectionSchemaElement|HiddenSectionSchemaElement
            if value_type == "table" then
                config[k] = build_config(elem.fields, v)
            else
                config[k] = build_config(elem.fields, {})
            end
        else
            ---@type SchemaType[]
            local elem_types
            if type(elem.type) == "string" then
                elem_types = { elem.type }
            else
                ---@type SchemaType[]
                elem_types = elem.type
            end

            if vim.tbl_contains(elem_types, value_type) then
                config[k] = v
            else
                config[k] = elem.default
            end
        end
    end

    return config
end

---comment
---@param user_config table<string,any>|nil
---@return Config
function M.build(user_config)
    user_config = user_config or {}
    local config_type = type(user_config)
    if config_type ~= "table" then
        warn("Expected config of type 'table' found '%s'", config_type)
        user_config = {}
    end

    handle_deprecated({}, M.schema, user_config, user_config)
    validate_schema({}, M.schema, user_config)
    return build_config(M.schema, user_config)
end

return M
