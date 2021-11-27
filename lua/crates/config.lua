local M = {Config = {TextConfig = {}, HighlightConfig = {}, PopupConfig = {}, PopupTextConfig = {}, PopupHighlightConfig = {}, PopupKeyConfig = {}, CmpConfig = {}, CmpTextConfig = {}, }, SchemaElement = {Deprecated = {}, }, }

















































































































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


               select = {
                  type = "table",
                  default = { "<cr>" },
               },
               select_dumb = {
                  type = "table",
                  default = { "s" },
               },
               copy_version = {
                  type = "table",
                  default = { "yy" },
               },


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

local function warn(s, ...)
   vim.notify(s:format(...), vim.log.levels.WARN, { title = "crates" })
end

local function join_path(path, component)
   local p = {}
   for i, c in ipairs(path) do
      p[i] = c
   end
   table.insert(p, component)
   return p
end

local function validate_schema(path, schema, user_config)
   for k, v in pairs(user_config) do
      local elem = schema[k]
      if elem then
         local value_type = type(v)
         if elem.type == "section" then
            local p = join_path(path, k)

            if value_type == "table" then
               validate_schema(p, elem.fields, v)
            else
               warn(
               "Config field %s was expected to be of type 'table' but was '%s'",
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

            local p = join_path(path, k)
            if not vim.tbl_contains(elem_types, value_type) then
               warn(
               "Config field %s was expected to be of type '%s' but was '%s', using default value.",
               table.concat(p, "."),
               table.concat(elem_types, " or "),
               value_type)

            end
         end
      else
         local p = join_path(path, k)
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

   validate_schema({}, M.schema, user_config)

   return build_config(M.schema, user_config)
end


return M
