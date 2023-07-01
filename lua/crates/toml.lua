local M = {Section = {}, Crate = {Vers = {}, Path = {}, Git = {}, Pkg = {}, Workspace = {}, Def = {}, Feat = {}, }, Feature = {}, Quotes = {}, }

















































































































local Section = M.Section
local Crate = M.Crate
local Feature = M.Feature
local semver = require("crates.semver")
local types = require("crates.types")
local Range = types.Range
local Requirement = types.Requirement

function M.parse_crate_features(text)
   local feats = {}
   for fds, qs, fs, f, fe, qe, fde, c in text:gmatch([[[,]?()%s*(["'])()([^,"']*)()(["']?)%s*()([,]?)]]) do
      table.insert(feats, {
         name = f,
         col = Range.new(fs - 1, fe - 1),
         decl_col = Range.new(fds - 1, fde - 1),
         quote = { s = qs, e = qe ~= "" and qe or nil },
         comma = c == ",",
      })
   end

   return feats
end

function Crate.new(obj)
   if obj.vers then
      obj.vers.reqs = semver.parse_requirements(obj.vers.text)

      obj.vers.is_pre = false
      for _, r in ipairs(obj.vers.reqs) do
         if r.vers.pre then
            obj.vers.is_pre = true
            break
         end
      end
   end
   if obj.feat then
      obj.feat.items = M.parse_crate_features(obj.feat.text)
   end
   if obj.def then
      obj.def.enabled = obj.def.text ~= "false"
   end
   if obj.workspace then
      obj.workspace.enabled = obj.workspace.text ~= "false"
   end

   return setmetatable(obj, { __index = Crate })
end

function Crate:vers_reqs()
   return self.vers and self.vers.reqs or {}
end

function Crate:vers_is_pre()
   return self.vers and self.vers.is_pre
end

function Crate:get_feat(name)
   if not self.feat or not self.feat.items then
      return nil
   end

   for i, f in ipairs(self.feat.items) do
      if f.name == name then
         return f, i
      end
   end

   return nil
end

function Crate:feats()
   return self.feat and self.feat.items or {}
end

function Crate:is_def_enabled()
   return not self.def or self.def.enabled
end

function Crate:is_workspace()
   return not self.workspace or self.workspace.enabled
end

function Crate:package()
   return self.pkg and self.pkg.text or self.explicit_name
end

function Crate:cache_key()
   return string.format(
   "%s:%s:%s:%s",
   self.section.target or "",
   self.section.workspace and "workspace" or "",
   self.section.kind,
   self.explicit_name)

end

function Section.new(obj)
   return setmetatable(obj, { __index = Section })
end

function Section:display(override_name)
   local text = "["

   if self.target then
      text = text .. self.target .. "."
   end

   if self.workspace then
      text = text .. "workspace."
   end

   if self.kind == "default" then
      text = text .. "dependencies"
   elseif self.kind == "dev" then
      text = text .. "dev-dependencies"
   elseif self.kind == "build" then
      text = text .. "build-dependencies"
   end

   local name = override_name or self.name
   if name then
      text = text .. "." .. name
   end

   text = text .. "]"

   return text
end

function M.parse_section(text, start)
   local prefix, suffix_s, suffix = text:match("^(.*)dependencies()(.*)$")
   if prefix and suffix then
      prefix = vim.trim(prefix)
      suffix = vim.trim(suffix)
      local section = {
         text = text,
         invalid = false,
         kind = "default",
      }

      local target = prefix

      local dev_target = prefix:match("^(.*)dev%-$")
      if dev_target then
         target = vim.trim(dev_target)
         section.kind = "dev"
      end

      local build_target = prefix:match("^(.*)build%-$")
      if build_target then
         target = vim.trim(build_target)
         section.kind = "build"
      end

      local workspace_target = target:match("^(.*)workspace%s*%.$")
      if workspace_target then
         section.workspace = true
         target = vim.trim(workspace_target)
      end

      if target then
         local t = target:match("^target%s*%.(.+)%.$")
         if t then
            section.target = vim.trim(t)
            target = ""
         end
      end

      if suffix then
         local n_s, n, n_e = suffix:match("^%.%s*()(.+)()%s*$")
         if n then
            section.name = vim.trim(n)
            local offset = start + suffix_s - 1
            section.name_col = Range.new(n_s - 1 + offset, n_e - 1 + offset)
            suffix = ""
         end
      end

      section.invalid = (target ~= "" or suffix ~= "") or
      (section.workspace and section.kind ~= "default") or
      (section.workspace and section.target ~= nil)

      return Section.new(section)
   end

   return nil
end


local function parse_crate_table_str(line, line_nr, pattern)
   local quote_s, str_s, text, str_e, quote_e = line:match(pattern)
   if text then
      return {
         text = text,
         line = line_nr,
         col = Range.new(str_s - 1, str_e - 1),
         decl_col = Range.new(0, line:len()),
         quote = { s = quote_s, e = quote_e ~= "" and quote_e or nil },
      }
   end

   return nil
end

local function parse_crate_table_bool(line, line_nr, pattern)
   local bool_s, text, bool_e = line:match(pattern)
   if text then
      return {
         text = text,
         line = line_nr,
         col = Range.new(bool_s - 1, bool_e - 1),
         decl_col = Range.new(0, line:len()),
      }
   end

   return nil
end

function M.parse_crate_table_vers(line, line_nr)
   local pat = [[^%s*version%s*=%s*(["'])()([^"']*)()(["']?)%s*$]]
   return parse_crate_table_str(line, line_nr, pat)
end

function M.parse_crate_table_path(line, line_nr)
   local pat = [[^%s*path%s*=%s*(["'])()([^"']*)()(["']?)%s*$]]
   return parse_crate_table_str(line, line_nr, pat)
end

function M.parse_crate_table_git(line, line_nr)
   local pat = [[^%s*git%s*=%s*(["'])()([^"']*)()(["']?)%s*$]]
   return parse_crate_table_str(line, line_nr, pat)
end

function M.parse_crate_table_pkg(line, line_nr)
   local pat = [[^%s*package%s*=%s*(["'])()([^"']*)()(["']?)%s*$]]
   return parse_crate_table_str(line, line_nr, pat)
end

function M.parse_crate_table_def(line, line_nr)
   local pat = "^%s*default[_-]features%s*=%s*()([^%s]*)()%s*$"
   return parse_crate_table_bool(line, line_nr, pat)
end

function M.parse_crate_table_workspace(line, line_nr)
   local pat = "^%s*workspace%s*=%s*()([^%s]*)()%s*$"
   return parse_crate_table_bool(line, line_nr, pat)
end

function M.parse_crate_table_feat(line, line_nr)
   local array_s, text, array_e = line:match("%s*features%s*=%s*%[()([^%]]*)()[%]]?%s*$")
   if text then
      return {
         text = text,
         line = line_nr,
         col = Range.new(array_s - 1, array_e - 1),
         decl_col = Range.new(0, line:len()),
      }
   end

   return nil
end


local function inline_table_bool_pattern(name)
   return "^%s*()([^%s]+)()%s*=%s*{.-[,]?()%s*" .. name .. "%s*=%s*()([^%s,}]*)()%s*()[,]?.*[}]?%s*$"
end

local function inline_table_str_pattern(name)
   return [[^%s*()([^%s]+)()%s*=%s*{.-[,]?()%s*]] .. name .. [[%s*=%s*(["'])()([^"']*)()(["']?)%s*()[,]?.*[}]?%s*$]]
end

local function inline_table_str_array_pattern(name)
   return "^%s*()([^%s]+)()%s*=%s*{.-[,]?()%s*" .. name .. "%s*=%s*%[()([^%]]*)()[%]]?%s*()[,]?.*[}]?%s*$"
end

local INLINE_TABLE_VERS_PATTERN = inline_table_str_pattern("version")
local INLINE_TABLE_PATH_PATTERN = inline_table_str_pattern("path")
local INLINE_TABLE_GIT_PATTERN = inline_table_str_pattern("git")
local INLINE_TABLE_PKG_PATTERN = inline_table_str_pattern("package")
local INLINE_TABLE_FEAT_PATTERN = inline_table_str_array_pattern("features")
local INLINE_TABLE_DEF_PATTERN = inline_table_bool_pattern("default[_-]features")
local INLINE_TABLE_WORKSPACE_PATTERN = inline_table_bool_pattern("workspace")

local function parse_inline_table_str(crate, line, line_nr, entry, pattern)
   local name_s, name, name_e, decl_s, quote_s, str_s, text, str_e, quote_e, decl_e = line:match(pattern)
   if name then
      crate.explicit_name = name
      crate.explicit_name_col = Range.new(name_s - 1, name_e - 1)
      do
         (crate)[entry] = {
            text = text,
            line = line_nr,
            col = Range.new(str_s - 1, str_e - 1),
            decl_col = Range.new(decl_s - 1, decl_e - 1),
            quote = { s = quote_s, e = quote_e ~= "" and quote_e or nil },
         }
      end
   end
end

local function parse_inline_table_bool(crate, line, line_nr, entry, pattern)
   local name_s, name, name_e, decl_s, str_s, text, str_e, decl_e = line:match(pattern)
   if name then
      crate.explicit_name = name
      crate.explicit_name_col = Range.new(name_s - 1, name_e - 1)
      do
         (crate)[entry] = {
            text = text,
            line = line_nr,
            col = Range.new(str_s - 1, str_e - 1),
            decl_col = Range.new(decl_s - 1, decl_e - 1),
         }
      end
   end
end

function M.parse_inline_crate(line, line_nr)

   do
      local name_s, name, name_e, quote_s, str_s, text, str_e, quote_e = line:match([[^%s*()([^%s]+)()%s*=%s*(["'])()([^"']*)()(["']?)%s*$]])
      if name then
         return {
            explicit_name = name,
            explicit_name_col = Range.new(name_s - 1, name_e - 1),
            lines = Range.new(line_nr, line_nr + 1),
            syntax = "plain",
            vers = {
               text = text,
               line = line_nr,
               col = Range.new(str_s - 1, str_e - 1),
               decl_col = Range.new(0, line:len()),
               quote = { s = quote_s, e = quote_e ~= "" and quote_e or nil },
            },
         }
      end
   end


   local crate = {
      syntax = "inline_table",
      lines = Range.new(line_nr, line_nr + 1),
   }

   parse_inline_table_str(crate, line, line_nr, "vers", INLINE_TABLE_VERS_PATTERN)
   parse_inline_table_str(crate, line, line_nr, "path", INLINE_TABLE_PATH_PATTERN)
   parse_inline_table_str(crate, line, line_nr, "git", INLINE_TABLE_GIT_PATTERN)
   parse_inline_table_str(crate, line, line_nr, "pkg", INLINE_TABLE_PKG_PATTERN)

   parse_inline_table_bool(crate, line, line_nr, "def", INLINE_TABLE_DEF_PATTERN)
   parse_inline_table_bool(crate, line, line_nr, "workspace", INLINE_TABLE_WORKSPACE_PATTERN)

   do
      local name_s, name, name_e, decl_s, array_s, text, array_e, decl_e = line:match(INLINE_TABLE_FEAT_PATTERN)
      if name then
         crate.explicit_name = name
         crate.explicit_name_col = Range.new(name_s - 1, name_e - 1)
         crate.feat = {
            text = text,
            line = line_nr,
            col = Range.new(array_s - 1, array_e - 1),
            decl_col = Range.new(decl_s - 1, decl_e - 1),
         }
      end
   end

   if crate.explicit_name then
      return crate
   end

   return nil
end

function M.trim_comments(line)
   local uncommented = line:match("^([^#]*)#.*$")
   return uncommented or line
end

function M.parse_crates(buf)
   local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

   local sections = {}
   local crates = {}

   local dep_section = nil
   local dep_section_crate = nil

   for i, line in ipairs(lines) do
      line = M.trim_comments(line)
      local line_nr = i - 1

      local section_start, section_text = line:match("^%s*%[()(.+)%]%s*$")

      if section_text then
         if dep_section then

            dep_section.lines.e = line_nr


            if dep_section_crate then
               dep_section_crate.lines = dep_section.lines
               table.insert(crates, Crate.new(dep_section_crate))
            end
         end

         local section = M.parse_section(section_text, section_start - 1)

         if section then
            section.lines = Range.new(line_nr, nil)
            dep_section = section
            dep_section_crate = nil
            table.insert(sections, dep_section)
         else
            dep_section = nil
            dep_section_crate = nil
         end
      elseif dep_section and dep_section.name then
         local empty_crate = {
            explicit_name = dep_section.name,
            explicit_name_col = dep_section.name_col,
            section = dep_section,
            syntax = "table",
         }

         local vers = M.parse_crate_table_vers(line, line_nr)
         if vers then
            dep_section_crate = dep_section_crate or empty_crate
            dep_section_crate.vers = vers
         end

         local path = M.parse_crate_table_path(line, line_nr)
         if path then
            dep_section_crate = dep_section_crate or empty_crate
            dep_section_crate.path = path
         end

         local git = M.parse_crate_table_git(line, line_nr)
         if git then
            dep_section_crate = dep_section_crate or empty_crate
            dep_section_crate.git = git
         end

         local pkg = M.parse_crate_table_pkg(line, line_nr)
         if pkg then
            dep_section_crate = dep_section_crate or empty_crate
            dep_section_crate.pkg = pkg
         end

         local workspace = M.parse_crate_table_workspace(line, line_nr)
         if workspace then
            dep_section_crate = dep_section_crate or empty_crate
            dep_section_crate.workspace = workspace
         end

         local feat = M.parse_crate_table_feat(line, line_nr)
         if feat then
            dep_section_crate = dep_section_crate or empty_crate
            dep_section_crate.feat = feat
         end

         local def = M.parse_crate_table_def(line, line_nr)
         if def then
            dep_section_crate = dep_section_crate or empty_crate
            dep_section_crate.def = def
         end
      elseif dep_section then
         local crate = M.parse_inline_crate(line, line_nr)
         if crate then
            crate.section = dep_section
            table.insert(crates, Crate.new(crate))
         end
      end
   end

   if dep_section then

      dep_section.lines.e = #lines


      if dep_section_crate then
         dep_section_crate.lines = dep_section.lines
         table.insert(crates, Crate.new(dep_section_crate))
      end
   end

   return sections, crates
end

return M
