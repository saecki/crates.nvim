local M = {CrateVersions = {}, FeatureInfo = {}, }











local CrateVersions = M.CrateVersions
local FeatureInfo = M.FeatureInfo
local core = require('crates.core')
local semver = require('crates.semver')
local SemVer = semver.SemVer
local Requirement = semver.Requirement
local api = require('crates.api')
local Version = api.Version
local Features = api.Features
local Feature = api.Feature
local toml = require('crates.toml')
local Crate = toml.Crate
local CrateFeature = toml.CrateFeature
local Range = require('crates.types').Range

function M.current_buf()
   return vim.api.nvim_get_current_buf()
end

function M.get_lines_crates(lines)
   local crate_versions = {}

   local cur_buf = M.current_buf()
   local crates = core.crate_cache[cur_buf]
   if crates then
      for _, c in pairs(crates) do
         if lines:contains(c.lines.s) or c.lines:contains(lines.s) then
            table.insert(crate_versions, {
               crate = c,
               versions = core.vers_cache[c.name],
            })
         end
      end
   end

   return crate_versions
end

function M.get_newest(versions, avoid_pre, reqs)
   if not versions then
      return nil
   end

   local newest_yanked = nil
   local newest_pre = nil
   local newest = nil

   for _, v in ipairs(versions) do
      if not reqs or semver.matches_requirements(v.parsed, reqs) then
         if not v.yanked then
            if not avoid_pre or avoid_pre and not v.parsed.suffix then
               newest = v
               break
            else
               newest_pre = newest_pre or v
            end
         else
            newest_yanked = newest_yanked or v
         end
      end
   end

   return newest, newest_pre, newest_yanked
end

function M.is_feat_enabled(crate, feature)
   local enabled = crate:get_feat(feature.name) ~= nil
   if feature.name == "default" then
      return enabled or crate:is_def_enabled()
   else
      return enabled
   end
end

function M.features_info(crate, features)
   local info = {}

   local function update_transitive(f)
      for _, m in ipairs(f.members) do
         local tf = features:get_feat(m)
         if tf then
            local i = info[m]
            if i then
               if not i.transitive then
                  i.transitive = true
               end
            else
               info[m] = {
                  enabled = false,
                  transitive = true,
               }
               update_transitive(tf)
            end
         end
      end
   end

   for _, f in ipairs(features) do
      local enabled = M.is_feat_enabled(crate, f)
      local i = info[f.name]
      if i then
         i.enabled = enabled
      else
         info[f.name] = {
            enabled = enabled,
            transitive = false,
         }
      end

      if enabled then
         update_transitive(f)
      end
   end

   return info
end

function M.set_version(buf, crate, text)
   if not crate.vers then
      if crate.syntax == "table" then
         local line = crate.lines.s + 1
         vim.api.nvim_buf_set_lines(
         buf, line, line, false,
         { 'version = "' .. text .. '"' })

         return crate.lines:moved(0, 1)
      elseif crate.syntax == "inline_table" then
         local line = crate.lines.s
         local def_col_start = 0
         if crate.def then
            def_col_start = crate.def.decl_col.s
         end
         local feat_col_start = 0
         if crate.feat then
            feat_col_start = crate.feat.decl_col.s
         end
         local col = math.max(def_col_start, feat_col_start)
         vim.api.nvim_buf_set_text(
         buf, line, col, line, col,
         { ' version = "' .. text .. '",' })

         return Range.pos(line)
      elseif crate.syntax == "plain" then
         return Range.empty()
      end
   else
      local t = text
      if not crate.vers.quote.e then
         t = text .. crate.vers.quote.s
      end
      local line = crate.vers.line
      vim.api.nvim_buf_set_text(
      buf,
      line,
      crate.vers.col.s,
      line,
      crate.vers.col.e,
      { t })

      return Range.pos(line)
   end
end

local function replace_existing(r, version)
   if version.suffix then
      return version
   else
      return SemVer.new({
         major = version.major,
         minor = r.vers.minor and version.minor or nil,
         patch = r.vers.patch and version.patch or nil,
      })
   end
end

function M.set_version_smart(buf, crate, version)
   if not crate:vers_reqs() or #crate:vers_reqs() == 0 then
      return M.set_version(buf, crate, version:display())
   end

   local pos = 1
   local text = ""
   for _, r in ipairs(crate.vers.reqs) do
      if r.cond == "wl" then
         if version.suffix then
            text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. version:display()
         else
            local v = SemVer.new({
               major = r.vers.major and version.major or nil,
               minor = r.vers.minor and version.minor or nil,
            })
            local before = string.sub(crate.vers.text, pos, r.vers_col.s)
            local after = string.sub(crate.vers.text, r.vers_col.e + 1, r.cond_col.e)
            text = text .. before .. v:display() .. after
         end
      elseif r.cond == "tl" then
         local v = replace_existing(r, version)
         text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v:display()
      elseif r.cond == "cr" then
         local v = replace_existing(r, version)
         text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v:display()
      elseif r.cond == "bl" then
         local v = replace_existing(r, version)
         text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v:display()
      elseif r.cond == "lt" and not semver.matches_requirement(version, r) then
         local v = SemVer.new({
            major = version.major,
            minor = r.vers.minor and version.minor or nil,
            patch = r.vers.patch and version.patch or nil,
         })

         if v.patch then
            v.patch = v.patch + 1
         elseif v.minor then
            v.minor = v.minor + 1
         elseif v.major then
            v.major = v.major + 1
         end

         text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v:display()
      elseif r.cond == "le" and not semver.matches_requirement(version, r) then
         local v

         if version.suffix then
            v = version
         else
            v = SemVer.new({ major = version.major })
            if r.vers.minor or version.minor and version.minor > 0 then
               v.minor = version.minor
            end
            if r.vers.patch or version.patch and version.patch > 0 then
               v.minor = version.minor
               v.patch = version.patch
            end
         end

         text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v:display()
      elseif r.cond == "gt" then
         local v = SemVer.new({
            major = r.vers.major and version.major or nil,
            minor = r.vers.minor and version.minor or nil,
            patch = r.vers.patch and version.patch or nil,
         })

         if v.patch then
            v.patch = v.patch - 1
            if v.patch < 0 then
               v.patch = 0
               v.minor = v.minor - 1
            end
         elseif v.minor then
            v.minor = v.minor - 1
            if v.minor < 0 then
               v.minor = 0
               v.major = v.major - 1
            end
         elseif v.major then
            v.major = v.major - 1
            if v.major < 0 then
               v.major = 0
            end
         end

         text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v:display()
      elseif r.cond == "ge" then
         local v = replace_existing(r, version)
         text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v:display()
      else
         text = text .. string.sub(crate.vers.text, pos, r.vers_col.e)
      end

      pos = math.max(r.cond_col.e + 1, r.vers_col.e + 1)
   end
   text = text .. string.sub(crate.vers.text, pos)

   return M.set_version(buf, crate, text)
end

function M.upgrade_crates(crates, smart)
   if smart == nil then
      smart = core.cfg.smart_insert
   end

   for _, c in ipairs(crates) do
      local crate = c.crate
      local versions = c.versions

      local avoid_pre = core.cfg.avoid_prerelease and not crate:vers_has_suffix()
      local newest, newest_pre, newest_yanked = M.get_newest(versions, avoid_pre, nil)
      newest = newest or newest_pre or newest_yanked

      if newest then
         if smart then
            M.set_version_smart(0, crate, newest.parsed)
         else
            M.set_version(0, crate, newest.num)
         end
      end
   end
end

function M.update_crates(crates, smart)
   if smart == nil then
      smart = core.cfg.smart_insert
   end

   for _, c in ipairs(crates) do
      local crate = c.crate
      local versions = c.versions

      local avoid_pre = core.cfg.avoid_prerelease and not crate:vers_has_suffix()
      local match, match_pre, match_yanked = M.get_newest(versions, avoid_pre, crate:vers_reqs())
      match = match or match_pre or match_yanked

      if match then
         if smart then
            M.set_version_smart(0, crate, match.parsed)
         else
            M.set_version(0, crate, match.num)
         end
      end
   end
end

function M.enable_feature(buf, crate, feature)
   local t = '"' .. feature.name .. '"'
   if not crate.feat then
      if crate.syntax == "table" then
         local line = math.max(
         crate.vers and crate.vers.line or 0,
         crate.def and crate.def.line or 0) +
         1
         vim.api.nvim_buf_set_lines(
         buf, line, line, false,
         { "features = [" .. t .. "]" })

         return Range.pos(line)
      elseif crate.syntax == "plain" then
         t = ", features = [" .. t .. "] }"
         local line = crate.vers.line
         local col = crate.vers.col.e
         if crate.vers.quote.e then
            col = col + 1
         else
            t = crate.vers.quote.s .. t
         end
         vim.api.nvim_buf_set_text(buf, line, col, line, col, { t })

         vim.api.nvim_buf_set_text(
         buf,
         line,
         crate.vers.col.s - 1,
         line,
         crate.vers.col.s - 1,
         { "{ version = " })

         return Range.pos(line)
      elseif crate.syntax == "inline_table" then
         local line = crate.lines.s
         local vers_col_end = 0
         if crate.vers then
            vers_col_end = crate.vers.col.e
            if crate.vers.quote.e then
               vers_col_end = vers_col_end + 1
            end
         end
         local def_col_end = 0
         if crate.def then
            def_col_end = crate.def.col.e
         end
         local col = math.max(vers_col_end, def_col_end)
         vim.api.nvim_buf_set_text(
         buf, line, col, line, col,
         { ", features = [" .. t .. "]" })

         return Range.pos(line)
      end
   else
      local last_feat = crate.feat.items[#crate.feat.items]
      if last_feat and not last_feat.comma then
         t = ", " .. t
      end

      vim.api.nvim_buf_set_text(
      buf,
      crate.feat.line,
      crate.feat.col.e,
      crate.feat.line,
      crate.feat.col.e,
      { t })

      return Range.pos(crate.feat.line)
   end
end

function M.disable_feature(buf, crate, feature)
   local _, index = crate:get_feat(feature.name)

   local col_start = feature.decl_col.s
   local col_end = feature.decl_col.e
   if index == 1 then
      if #crate.feat.items > 1 then
         col_end = crate.feat.items[2].col.s - 1
      elseif feature.comma then
         col_end = col_end + 1
      end
   else
      local prev_feature = crate.feat.items[index - 1]
      col_start = prev_feature.col.e + 1
   end

   vim.api.nvim_buf_set_text(
   buf,
   crate.feat.line,
   crate.feat.col.s + col_start,
   crate.feat.line,
   crate.feat.col.s + col_end,
   { "" })

   return Range.pos(crate.feat.line)
end

function M.enable_def_features(buf, crate)
   vim.api.nvim_buf_set_text(
   buf,
   crate.def.line,
   crate.def.col.s,
   crate.def.line,
   crate.def.col.e,
   { "true" })

   return Range.pos(crate.def.line)
end

local function disable_def_features(buf, crate)
   if crate.def then
      local line = crate.def.line
      vim.api.nvim_buf_set_text(
      buf,
      line,
      crate.def.col.s,
      line,
      crate.def.col.e,
      { "false" })

      return crate.lines
   else
      if crate.syntax == "table" then
         local line = math.max((crate.vers.line or 0) + 1, crate.feat.line or 0)
         vim.api.nvim_buf_set_lines(
         buf,
         line,
         line,
         false,
         { "default_features = false" })

         return crate.lines:moved(0, 1)
      elseif crate.syntax == "plain" then
         local t = ", default_features = false }"
         local col = crate.vers.col.e
         if crate.vers.quote.e then
            col = col + 1
         else
            t = crate.vers.quote.s .. t
         end
         local line = crate.vers.line
         vim.api.nvim_buf_set_text(
         buf,
         line,
         col,
         line,
         col,
         { t })


         vim.api.nvim_buf_set_text(
         buf,
         line,
         crate.vers.col.s - 1,
         line,
         crate.vers.col.s - 1,
         { "{ version = " })

         return crate.lines
      elseif crate.syntax == "inline_table" then
         local line = crate.lines.s
         if crate.vers then
            local col = crate.vers.col.e
            if crate.vers.quote.e then
               col = col + 1
            end
            vim.api.nvim_buf_set_text(
            buf, line, col, line, col,
            { ", default_features = false" })

         elseif crate.feat then
            local col = crate.feat.decl_col.s
            vim.api.nvim_buf_set_text(
            buf, line, col, line, col,
            { " default_features = false," })

         end
         return crate.lines
      end
   end
end

function M.disable_def_features(buf, crate, feature)
   if feature then
      if crate.def and crate.def.col.s < crate.feat.col.s then
         M.disable_feature(buf, crate, feature)
         return disable_def_features(buf, crate)
      else
         local lines = disable_def_features(buf, crate)
         M.disable_feature(buf, crate, feature)
         return lines
      end
   else
      return disable_def_features(buf, crate)
   end
end

return M
