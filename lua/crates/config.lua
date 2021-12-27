local M = {Config = {TextConfig = {}, HighlightConfig = {}, DiagnosticConfig = {}, PopupConfig = {}, PopupTextConfig = {}, PopupHighlightConfig = {}, PopupKeyConfig = {}, CmpConfig = {}, CmpTextConfig = {}, }, SchemaElement = {Deprecated = {}, }, }





































































































































local Config = M.Config
local SchemaType = M.SchemaType
local SchemaElement = M.SchemaElement

local function entry(schema, name, elem)
   elem.name = name
   table.insert(schema, elem)
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
   default = "Error fetching crate information",
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
entry(schema_popup, "version_date", {
   type = "boolean",
   default = false,
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
   default = "  %s ",
   description = [[
        Format string used for the popup title.
    ]],
})

entry(schema_popup_text, "version", {
   type = "string",
   default = "   %s ",
   description = [[
        Format string used for release versions.
    ]],
})
entry(schema_popup_text, "prerelease", {
   type = "string",
   default = "  %s ",
   description = [[
        Format string used for prerelease versions.
    ]],
})
entry(schema_popup_text, "yanked", {
   type = "string",
   default = "  %s ",
   description = [[
        Format string used for yanked versions.
    ]],
})
entry(schema_popup_text, "date", {
   type = "string",
   default = " %s ",
   description = [[
        Format string used for appending the version release date.
    ]],
})

entry(schema_popup_text, "feature", {
   type = "string",
   default = "   %s ",
   description = [[
        Format string used for disabled features.
    ]],
})
entry(schema_popup_text, "enabled", {
   type = "string",
   default = "  %s ",
   description = [[
        Format string used for enabled features.
    ]],
})
entry(schema_popup_text, "transitive", {
   type = "string",
   default = "  %s ",
   description = [[
        Format string used for transitively enabled features.
    ]],
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
entry(schema_popup_keys, "copy_version", {
   type = "table",
   default = { "yy" },
   description = [[
        Key mappings to copy the version on the current line inside the popup.
    ]],
})

entry(schema_popup_keys, "toggle_feature", {
   type = "table",
   default = { "<cr>" },
   description = [[
        Key mappings to enable or disable the feature on the currentline inside the popup.
    ]],
})
entry(schema_popup_keys, "goto_feature", {
   type = "table",
   default = { "gd", "K" },
   description = [[
        Key mappings to go to the feature on the currentline inside the popup.
    ]],
})
entry(schema_popup_keys, "jump_forward_feature", {
   type = "table",
   default = { "<c-i>" },
   description = [[
        Key mappings to jump forward in the features jump history.
    ]],
})
entry(schema_popup_keys, "jump_back_feature", {
   type = "table",
   default = { "<c-o>" },
   description = [[
        Key mappings to jump back in the features jump history.
    ]],
})


entry(M.schema, "cmp", {
   type = "section",
   description = [[
        Configuration options for the |nvim-cmp| source.
    ]],
   fields = {},
})
local schema_cmp = M.schema.cmp.fields
entry(schema_cmp, "insert_closing_quote", {
   type = "boolean",
   default = true,
   description = [[
        Insert a closing quote on completion if there is none.
    ]],
})
entry(schema_cmp, "text", {
   type = "section",
   description = [[
        Text shown in the |nvim-cmp| documentation preview.
    ]],
   fields = {},
})
local schema_cmp_text = schema_cmp.text.fields
entry(schema_cmp_text, "prerelease", {
   type = "string",
   default = "  pre-release ",
   description = [[
        Text shown in the |nvim-cmp| documentation preview for pre-release versions.
    ]],
})
entry(schema_cmp_text, "yanked", {
   type = "string",
   default = "  yanked ",
   description = [[
        Text shown in the |nvim-cmp| documentation preview for yanked versions.
    ]],
})

local function warn(s, ...)
   vim.notify(s:format(...), vim.log.levels.WARN, { title = "crates.nvim" })
end

local function join_path(path, component)
   local p = {}
   for i, c in ipairs(path) do
      p[i] = c
   end
   table.insert(p, component)
   return p
end

local function table_set_path(t, path, value)
   local current = t
   for i, c in ipairs(path) do
      if i == #path then
         current[c] = value
      elseif type(current[c]) == "table" then
         current = current[c]
      elseif current[c] == nil then
         current[c] = {}
         current = current[c]
      else
         break
      end
   end
end

local function handle_deprecated(path, schema, root_config, user_config)
   for k, v in pairs(user_config) do
      local elem = schema[k]

      if elem then
         local p = join_path(path, k)
         local dep = elem.deprecated

         if dep then
            if dep.new_field and not dep.hard then
               table_set_path(root_config, dep.new_field, v)
            end
         elseif elem.type == "section" and type(v) == "table" then
            handle_deprecated(p, elem.fields, root_config, v)
         end
      end
   end
end

local function validate_schema(path, schema, user_config)
   for k, v in pairs(user_config) do
      local p = join_path(path, k)
      local elem = schema[k]

      if elem then
         local value_type = type(v)
         local dep = elem.deprecated

         if dep then
            if dep.new_field then
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
               table.concat(dep.new_field, "."))

            else
               warn(
               "'%s' is now deprecated, ignoring",
               table.concat(p, "."))

            end
         elseif elem.type == "section" then
            if value_type == "table" then
               validate_schema(p, elem.fields, v)
            else
               warn(
               "Config field '%s' was expected to be of type 'table' but was '%s', using default value.",
               table.concat(p, "."),
               value_type)

            end
         else
            local elem_types
            if type(elem.type) == "string" then
               elem_types = { elem.type }
            else
               elem_types = elem.type
            end

            if not vim.tbl_contains(elem_types, value_type) then
               warn(
               "Config field '%s' was expected to be of type '%s' but was '%s', using default value.",
               table.concat(p, "."),
               table.concat(elem_types, " or "),
               value_type)

            end
         end
      else
         warn(
         "Ignoring invalid config key '%s'",
         table.concat(p, "."))

      end
   end
end

local function build_config(schema, user_config)
   local config = {}

   for k, elem in pairs(schema) do
      local v = user_config[k]
      local value_type = type(v)

      if elem.type == "section" then
         if value_type == "table" then
            config[k] = build_config(elem.fields, v)
         else
            config[k] = build_config(elem.fields, {})
         end
      else
         local elem_types
         if type(elem.type) == "string" then
            elem_types = { elem.type }
         else
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
