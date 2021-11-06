local M = {Crate = {}, CrateFeature = {}, Quotes = {}, }





































local Crate = M.Crate
local CrateFeature = M.CrateFeature
local semver = require('crates.semver')
local Requirement = semver.Requirement
local Range = require('crates.types').Range

function M.parse_crate_features(text)
   local feats = {}
   for fds, qs, fs, f, fe, qe, fde, c in text:gmatch([[[,]?()%s*(["'])()([^,"']*)()(["']?)%s*()([,]?)]]) do
      table.insert(feats, {
         name = f,
         col = Range.new(fs - 1, fe - 1),
         decl_col = Range.new(fds - 1, fde - 1),
         quotes = { s = qs, e = qe ~= "" and qe or nil },
         comma = c == ",",
      })
   end

   return feats
end

function Crate.new(obj)
   if obj.req_text then
      obj.reqs = semver.parse_requirements(obj.req_text)

      obj.req_has_suffix = false
      for _, r in ipairs(obj.reqs) do
         if r.vers.suffix then
            obj.req_has_suffix = true
            break
         end
      end
   end
   if obj.feat_text then
      obj.feats = M.parse_crate_features(obj.feat_text)
   end
   if obj.def_text then
      obj.def = obj.def_text ~= "false"
   end

   return setmetatable(obj, { __index = Crate })
end

function Crate:get_feat(name)
   if not self.feats then return nil end

   for i, f in ipairs(self.feats) do
      if f.name == name then
         return f, i
      end
   end

   return nil
end


function M.parse_crate_table_req(line)
   local qs, vs, req_text, ve, qe = line:match([[^%s*version%s*=%s*(["'])()([^"']*)()(["']?)%s*$]])
   if qs and vs and req_text and ve then
      return {
         req_text = req_text,
         req_col = Range.new(vs - 1, ve - 1),
         req_decl_col = Range.new(0, line:len()),
         req_quote = { s = qs, e = qe ~= "" and qe or nil },
         syntax = "table",
      }
   end

   return nil
end

function M.parse_crate_table_feat(line)
   local fs, feat_text, fe = line:match("%s*features%s*=%s*%[()([^%]]*)()[%]]?%s*$")
   if fs and feat_text and fe then
      return {
         feat_text = feat_text,
         feat_col = Range.new(fs - 1, fe - 1),
         feat_decl_col = Range.new(0, line:len()),
         syntax = "table",
      }
   end

   return nil
end

function M.parse_crate_table_def(line)
   local ds, def_text, de = line:match("^%s*default[_-]features%s*=%s*()([^%s]*)()%s*$")
   if ds and def_text and de then
      return {
         def_text = def_text,
         def_col = Range.new(ds - 1, de - 1),
         def_decl_col = Range.new(0, line:len()),
         syntax = "table",
      }
   end

   return nil
end

function M.parse_crate(line)
   local name
   local vds, qs, vs, req_text, ve, qe, vde
   local fds, fs, feat_text, fe, fde
   local dds, ds, def_text, de, dde


   name, qs, vs, req_text, ve, qe = line:match([[^%s*([^%s]+)%s*=%s*(["'])()([^"']*)()(["']?)%s*$]])
   if name and qs and vs and req_text and ve then
      return {
         name = name,
         req_text = req_text,
         req_col = Range.new(vs - 1, ve - 1),
         req_decl_col = Range.new(0, line:len()),
         req_quote = { s = qs, e = qe },
         syntax = "plain",
      }
   end


   local crate = {}

   local vers_pat = [[^%s*([^%s]+)%s*=%s*{.-[,]?()%s*version%s*=%s*(["'])()([^"']*)()(["']?)%s*()[,]?.*[}]?%s*$]]
   name, vds, qs, vs, req_text, ve, qe, vde = line:match(vers_pat)
   if name and vds and qs and vs and req_text and ve and qe and vde then
      crate.name = name
      crate.req_text = req_text
      crate.req_col = Range.new(vs - 1, ve - 1)
      crate.req_decl_col = Range.new(vds - 1, vde - 1)
      crate.req_quote = { s = qs, e = qe ~= "" and qe or nil }
      crate.syntax = "inline_table"
   end

   local feat_pat = "^%s*([^%s]+)%s*=%s*{.-[,]?()%s*features%s*=%s*%[()([^%]]*)()[%]]?%s*()[,]?.*[}]?%s*$"
   name, fds, fs, feat_text, fe, fde = line:match(feat_pat)
   if name and fds and fs and feat_text and fe and fde then
      crate.name = name
      crate.feat_text = feat_text
      crate.feat_col = Range.new(fs - 1, fe - 1)
      crate.feat_decl_col = Range.new(fds - 1, fde - 1)
      crate.syntax = "inline_table"
   end

   local def_pat = "^%s*([^%s]+)%s*=%s*{.-[,]?()%s*default[_-]features%s*=%s*()([a-zA-Z]*)()%s*()[,]?.*[}]?%s*$"
   name, dds, ds, def_text, de, dde = line:match(def_pat)
   if name and dds and ds and def_text and de and dde then
      crate.name = name
      crate.def_text = def_text
      crate.def_col = Range.new(ds - 1, de - 1)
      crate.def_decl_col = Range.new(dds - 1, dde - 1)
      crate.syntax = "inline_table"
   end

   if crate.name then
      return crate
   else
      return nil
   end
end

function M.trim_comments(line)
   local uncommented = line:match("^([^#]*)#.*$")
   return uncommented or line
end

function M.parse_crates(buf)
   local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

   local crates = {}
   local in_dep_table = false
   local dep_table_start = 0
   local dep_table_crate = nil
   local dep_table_crate_name = nil

   for i, l in ipairs(lines) do
      l = M.trim_comments(l)

      local section = l:match("^%s*%[(.+)%]%s*$")

      if section then

         if dep_table_crate then
            dep_table_crate.lines = Range.new(dep_table_start, i - 1)
            table.insert(crates, Crate.new(dep_table_crate))
         end

         local c = section:match("^.*dependencies(.*)$")
         if c then
            in_dep_table = true
            dep_table_start = i - 1
            dep_table_crate = nil
            dep_table_crate_name = c:match("^%.(.+)$")
         else
            in_dep_table = false
            dep_table_crate = nil
            dep_table_crate_name = nil
         end
      elseif in_dep_table and dep_table_crate_name then
         local crate_req = M.parse_crate_table_req(l)
         if crate_req then
            crate_req.name = dep_table_crate_name
            crate_req.req_line = i - 1
            dep_table_crate = vim.tbl_extend("keep", dep_table_crate or {}, crate_req)
         end

         local crate_feat = M.parse_crate_table_feat(l)
         if crate_feat then
            crate_feat.name = dep_table_crate_name
            crate_feat.feat_line = i - 1
            dep_table_crate = vim.tbl_extend("keep", dep_table_crate or {}, crate_feat)
         end

         local crate_def = M.parse_crate_table_def(l)
         if crate_def then
            crate_def.name = dep_table_crate_name
            crate_def.def_line = i - 1
            dep_table_crate = vim.tbl_extend("keep", dep_table_crate or {}, crate_def)
         end
      elseif in_dep_table then
         local crate = M.parse_crate(l)
         if crate then
            crate.lines = Range.new(i - 1, i)
            crate.req_line = i - 1
            crate.feat_line = i - 1
            crate.def_line = i - 1
            table.insert(crates, Crate.new(crate))
         end
      end
   end


   if dep_table_crate then
      dep_table_crate.lines = Range.new(dep_table_start, #lines - 1)
      table.insert(crates, Crate.new(dep_table_crate))
   end

   return crates
end

return M
