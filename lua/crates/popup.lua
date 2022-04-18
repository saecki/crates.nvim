local M = {FeatureContext = {}, FeatHistoryEntry = {}, DepsContext = {}, DepsHistoryEntry = {}, WinOpts = {}, HighlightText = {}, LineCrateInfo = {}, }









































































local FeatureContext = M.FeatureContext
local FeatHistoryEntry = M.FeatHistoryEntry
local DepsContext = M.DepsContext
local WinOpts = M.WinOpts
local HighlightText = M.HighlightText
local LineCrateInfo = M.LineCrateInfo
local core = require("crates.core")
local state = require("crates.state")
local api = require("crates.api")
local Version = api.Version
local Feature = api.Feature
local Dependency = api.Dependency
local toml = require("crates.toml")
local Crate = toml.Crate
local util = require("crates.util")
local FeatureInfo = util.FeatureInfo
local Range = require("crates.types").Range

local top_offset = 2

M.namespace = vim.api.nvim_create_namespace("crates.nvim.popup")

local function line_crate_info()
   local pos = vim.api.nvim_win_get_cursor(0)
   local line = pos[1] - 1
   local col = pos[2]

   local crates = util.get_lines_crates(Range.new(line, line + 1))
   if not crates or not crates[1] or not crates[1].versions then
      return nil
   end
   local crate = crates[1].crate
   local versions = crates[1].versions

   local avoid_pre = core.cfg.avoid_prerelease and not crate:vers_is_pre()
   local newest = util.get_newest(versions, avoid_pre, crate:vers_reqs())

   local info = {
      crate = crate,
      versions = versions,
      newest = newest,
   }

   local function versions_info()
      info.pref = "versions"
   end

   local function features_info()
      for _, cf in ipairs(crate.feat.items) do
         if cf.decl_col:contains(col - crate.feat.col.s) then
            info.feature = newest.features:get_feat(cf.name)
            break
         end
      end

      if info.feature then
         info.pref = "feature_details"
      else
         info.pref = "features"
      end
   end

   local function default_features_info()
      info.feature = newest.features:get_feat("default") or {
         name = "default",
         members = {},
      }
      info.pref = "feature_details"
   end

   if crate.syntax == "plain" then
      versions_info()
   elseif crate.syntax == "table" then
      if crate.feat and line == crate.feat.line then
         features_info()
      elseif crate.def and line == crate.def.line then
         default_features_info()
      else
         versions_info()
      end
   elseif crate.syntax == "inline_table" then
      if crate.feat and line == crate.feat.line and crate.feat.decl_col:contains(col) then
         features_info()
      elseif crate.def and line == crate.def.line and crate.def.decl_col:contains(col) then
         default_features_info()
      else
         versions_info()
      end
   end

   return info
end

function M.show()
   if M.win and vim.api.nvim_win_is_valid(M.win) then
      M.focus()
      return
   end

   local info = line_crate_info()
   if not info then return end

   if info.pref == "versions" then
      M.open_versions(info.crate, info.versions)
   elseif info.pref == "features" then
      M.open_features(info.crate, info.newest, {})
   elseif info.pref == "feature_details" then
      M.open_feature_details(info.crate, info.newest, info.feature, {})
   elseif info.pref == "dependencies" then
      M.open_deps(info.crate.name, info.newest, {})
   end
end

function M.show_versions()
   if M.win and vim.api.nvim_win_is_valid(M.win) then
      if M.type == "versions" then
         M.focus()
         return
      else
         M.hide()
      end
   end

   local info = line_crate_info()
   if not info then return end

   M.open_versions(info.crate, info.versions)
end

function M.show_features()
   if M.win and vim.api.nvim_win_is_valid(M.win) then
      if M.type == "features" then
         M.focus()
         return
      else
         M.hide()
      end
   end

   local info = line_crate_info()
   if not info then return end

   if info.pref == "features" then
      M.open_features(info.crate, info.newest, {})
   elseif info.pref == "feature_details" then
      M.open_feature_details(info.crate, info.newest, info.feature, {})
   elseif info.newest then
      M.open_features(info.crate, info.newest, {})
   end
end

function M.show_dependencies()
   if M.win and vim.api.nvim_win_is_valid(M.win) then
      if M.type == "dependencies" then
         M.focus()
         return
      else
         M.hide()
      end
   end

   local info = line_crate_info()
   if not info then return end

   M.open_deps(info.crate.name, info.newest, {})
end

function M.focus(line)
   if M.win and vim.api.nvim_win_is_valid(M.win) then
      vim.api.nvim_set_current_win(M.win)
      local l = math.min(line or 3, vim.api.nvim_buf_line_count(M.buf))
      vim.api.nvim_win_set_cursor(M.win, { l, 0 })
   end
end

function M.hide()
   if M.win and vim.api.nvim_win_is_valid(M.win) then
      vim.api.nvim_win_close(M.win, false)
   end
   M.win = nil

   if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
      vim.api.nvim_buf_delete(M.buf, {})
   end
   M.buf = nil
   M.type = nil
   M.feat_ctx = nil
   M.deps_ctx = nil
end

local function win_height(entries)
   return math.min(
   #entries + top_offset,
   core.cfg.popup.max_height)

end

local function win_width(title, content_width)
   return math.max(
   vim.fn.strdisplaywidth(title) + vim.fn.strdisplaywidth(core.cfg.popup.text.loading),
   content_width,
   core.cfg.popup.min_width)

end

local function set_buf_content(buf, title, text)
   vim.api.nvim_buf_set_option(buf, "modifiable", true)


   vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
   vim.api.nvim_buf_clear_namespace(buf, M.namespace, 0, -1)


   vim.api.nvim_buf_set_lines(buf, 0, 2, false, { title, "" })
   vim.api.nvim_buf_add_highlight(buf, M.namespace, core.cfg.popup.highlight.title, 0, 0, -1)

   for i, v in ipairs(text) do
      vim.api.nvim_buf_set_lines(buf, top_offset + i - 1, top_offset + i, false, { v.text .. (v.suffix or "") })
      vim.api.nvim_buf_add_highlight(buf, M.namespace, v.hl, top_offset + i - 1, 0, v.text:len())
      if v.suffix_hl then
         vim.api.nvim_buf_add_highlight(buf, M.namespace, v.suffix_hl, top_offset + i - 1, v.text:len(), -1)
      end
   end

   vim.api.nvim_buf_set_name(buf, "crates")
   vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

local function update_win(width, height, title, text, opts)

   vim.api.nvim_win_set_width(M.win, width)
   vim.api.nvim_win_set_height(M.win, height)


   set_buf_content(M.buf, title, text)


   local l = math.min(opts.line or 3, vim.api.nvim_buf_line_count(M.buf))
   vim.api.nvim_win_set_cursor(M.win, { l, 0 })
end

local function open_win(width, height, title, text, opts, configure)
   M.buf = vim.api.nvim_create_buf(false, true)


   set_buf_content(M.buf, title, text)


   M.win = vim.api.nvim_open_win(M.buf, false, {
      relative = "cursor",
      col = 0,
      row = 1,
      width = width,
      height = height,
      style = core.cfg.popup.style,
      border = core.cfg.popup.border,
   })


   local hide_cmd = ":lua require('crates.popup').hide()<cr>"
   for _, k in ipairs(core.cfg.popup.keys.hide) do
      vim.api.nvim_buf_set_keymap(M.buf, "n", k, hide_cmd, { noremap = true, silent = true })
   end

   if configure then
      configure()
   end


   if opts and opts.focus or core.cfg.popup.autofocus then
      M.focus(opts and opts.line)
   end
end


function M.open_versions(crate, versions, opts)
   M.type = "versions"
   local title = string.format(core.cfg.popup.text.title, crate.name)
   local vers_width = 0
   local versions_text = {}

   for _, v in ipairs(versions) do
      local text, hl
      if v.yanked then
         text = string.format(core.cfg.popup.text.yanked, v.num)
         hl = core.cfg.popup.highlight.yanked
      elseif v.parsed.pre then
         text = string.format(core.cfg.popup.text.prerelease, v.num)
         hl = core.cfg.popup.highlight.prerelease
      else
         text = string.format(core.cfg.popup.text.version, v.num)
         hl = core.cfg.popup.highlight.version
      end

      table.insert(versions_text, { text = text, hl = hl })
      vers_width = math.max(vim.fn.strdisplaywidth(text), vers_width)
   end

   local date_width = 0
   if core.cfg.popup.show_version_date then
      for i, v in ipairs(versions_text) do
         local diff = vers_width - vim.fn.strdisplaywidth(v.text)
         local date = versions[i].created:display(core.cfg.date_format)
         v.text = v.text .. string.rep(" ", diff)
         v.suffix = string.format(core.cfg.popup.text.version_date, date)
         v.suffix_hl = core.cfg.popup.highlight.version_date

         date_width = math.max(vim.fn.strdisplaywidth(v.suffix), date_width)
      end
   end

   local width = win_width(title, vers_width + date_width)
   local height = win_height(versions)
   open_win(width, height, title, versions_text, opts, function()
      local select_cmd = string.format(
      ":lua require('crates.popup').select_version(%d, '%s', %s - %d)<cr>",
      util.current_buf(),
      crate:cache_key(),
      "vim.api.nvim_win_get_cursor(0)[1]",
      top_offset)

      for _, k in ipairs(core.cfg.popup.keys.select) do
         vim.api.nvim_buf_set_keymap(M.buf, "n", k, select_cmd, { noremap = true, silent = true })
      end

      local select_alt_cmd = string.format(
      ":lua require('crates.popup').select_version(%d, '%s', %s - %d, true)<cr>",
      util.current_buf(),
      crate:cache_key(),
      "vim.api.nvim_win_get_cursor(0)[1]",
      top_offset)

      for _, k in ipairs(core.cfg.popup.keys.select_alt) do
         vim.api.nvim_buf_set_keymap(M.buf, "n", k, select_alt_cmd, { noremap = true, silent = true })
      end

      local copy_cmd = string.format(
      ":lua require('crates.popup').copy_version('%s', %s - %d, true)<cr>",
      crate.name,
      "vim.api.nvim_win_get_cursor(0)[1]",
      top_offset)

      for _, k in ipairs(core.cfg.popup.keys.copy_version) do
         vim.api.nvim_buf_set_keymap(M.buf, "n", k, copy_cmd, { noremap = true, silent = true })
      end
   end)
end

function M.select_version(buf, key, index, alt)
   local crates = core.crate_cache[buf]
   if not crates then return end

   local crate = crates[key]
   if not crate then return end

   local versions = core.vers_cache[crate.name]
   if not versions then return end

   local version = versions[index]
   if not version then return end

   local line_range
   line_range = util.set_version(buf, crate, version.parsed, alt)


   for l in line_range:iter() do
      local line = vim.api.nvim_buf_get_lines(buf, l, l + 1, false)[1]
      line = toml.trim_comments(line)
      if crate.syntax == "table" then
         local c = toml.parse_crate_table_vers(line)
         if c and c.vers then
            crate.vers.line = l
            crate.vers.col = c.vers.col
            crate.vers.decl_col = c.vers.decl_col
            crate.vers.quote = c.vers.quote
         end
      elseif crate.syntax == "plain" or crate.syntax == "inline_table" then
         local c = toml.parse_crate(line)
         if c and c.vers then
            crate.vers.line = l
            crate.vers.col = c.vers.col
            crate.vers.decl_col = c.vers.decl_col
            crate.vers.quote = c.vers.quote
         end
      end
   end
end

function M.copy_version(name, index)
   local versions = core.vers_cache[name]
   if not versions then return end

   if index <= 0 or index > #versions then
      return
   end
   local text = versions[index].num

   vim.fn.setreg(core.cfg.popup.copy_register, text)
end


local function feature_text(features_info, feature)
   local text, hl
   local info = features_info[feature.name]
   if info.enabled then
      text = string.format(core.cfg.popup.text.enabled, feature.name)
      hl = core.cfg.popup.highlight.enabled
   elseif info.transitive then
      text = string.format(core.cfg.popup.text.transitive, feature.name)
      hl = core.cfg.popup.highlight.transitive
   else
      text = string.format(core.cfg.popup.text.feature, feature.name)
      hl = core.cfg.popup.highlight.feature
   end
   return { text = text, hl = hl }
end

local function config_feat_win()
   local toggle_cmd = string.format(
   ":lua require('crates.popup').toggle_feature(%s - %d)<cr>",
   "vim.api.nvim_win_get_cursor(0)[1]",
   top_offset)

   for _, k in ipairs(core.cfg.popup.keys.toggle_feature) do
      vim.api.nvim_buf_set_keymap(M.buf, "n", k, toggle_cmd, { noremap = true, silent = true })
   end

   local goto_cmd = string.format(
   ":lua require('crates.popup').goto_feature(%s - %d)<cr>",
   "vim.api.nvim_win_get_cursor(0)[1]",
   top_offset)

   for _, k in ipairs(core.cfg.popup.keys.goto_item) do
      vim.api.nvim_buf_set_keymap(M.buf, "n", k, goto_cmd, { noremap = true, silent = true })
   end

   local jump_forward_cmd = string.format(
   ":lua require('crates.popup').jump_forward_feature(%s)<cr>",
   "vim.api.nvim_win_get_cursor(0)[1]")

   for _, k in ipairs(core.cfg.popup.keys.jump_forward) do
      vim.api.nvim_buf_set_keymap(M.buf, "n", k, jump_forward_cmd, { noremap = true, silent = true })
   end

   local jump_back_cmd = string.format(
   ":lua require('crates.popup').jump_back_feature(%s)<cr>",
   "vim.api.nvim_win_get_cursor(0)[1]")

   for _, k in ipairs(core.cfg.popup.keys.jump_back) do
      vim.api.nvim_buf_set_keymap(M.buf, "n", k, jump_back_cmd, { noremap = true, silent = true })
   end
end

function M.open_features(crate, version, opts)
   M.feat_ctx = {
      buf = util.current_buf(),
      crate = crate,
      version = version,
      history = {
         { feature = nil, line = opts and opts.line or 3 },
      },
      history_index = 1,
   }
   M._open_features(crate, version, opts)
end

function M._open_features(crate, version, opts)
   M.type = "features"

   local features = version.features
   local title = string.format(core.cfg.popup.text.title, crate.name .. " " .. version.num)
   local feat_width = 0
   local features_text = {}

   local features_info = util.features_info(crate, features)
   for _, f in ipairs(features) do
      local hi_text = feature_text(features_info, f)
      table.insert(features_text, hi_text)
      feat_width = math.max(vim.fn.strdisplaywidth(hi_text.text), feat_width)
   end

   local width = win_width(title, feat_width)
   local height = win_height(features)

   if opts.update then
      update_win(width, height, title, features_text, opts)
   else
      open_win(width, height, title, features_text, opts, config_feat_win)
   end
end

function M.open_feature_details(crate, version, feature, opts)
   M.feat_ctx = {
      buf = util.current_buf(),
      crate = crate,
      version = version,
      history = {
         { feature = nil, line = 3 },
         { feature = feature, line = opts and opts.line or 3 },
      },
      history_index = 2,
   }
   M._open_feature_details(crate, version, feature, opts)
end

function M._open_feature_details(crate, version, feature, opts)
   M.type = "features"

   local features = version.features
   local members = feature.members
   local title = string.format(core.cfg.popup.text.title, crate.name .. " " .. version.num .. " " .. feature.name)
   local feat_width = 0
   local features_text = {}

   local features_info = util.features_info(crate, features)
   for _, m in ipairs(members) do
      local f = features:get_feat(m) or {
         name = m,
         members = {},
      }

      local hi_text = feature_text(features_info, f)
      table.insert(features_text, hi_text)
      feat_width = math.max(hi_text.text:len(), feat_width)
   end

   local width = win_width(title, feat_width)
   local height = win_height(members)

   if opts.update then
      update_win(width, height, title, features_text, opts)
   else
      open_win(width, height, title, features_text, opts, config_feat_win)
   end
end

function M.toggle_feature(index)
   if not M.feat_ctx then return end
   local feat_ctx = M.feat_ctx

   local buf = feat_ctx.buf
   local crate = feat_ctx.crate
   local version = feat_ctx.version
   local features = version.features
   local hist_index = feat_ctx.history_index
   local feature = feat_ctx.history[hist_index].feature

   local selected_feature
   if feature then
      local m = feature.members[index]
      if m then
         selected_feature = features:get_feat(m)
      end
   else
      selected_feature = features[index]
   end
   if not selected_feature then return end

   local line_range
   local crate_feature = crate:get_feat(selected_feature.name)
   if selected_feature.name == "default" then
      if crate_feature ~= nil or crate:is_def_enabled() then
         line_range = util.disable_def_features(buf, crate, crate_feature)
      else
         line_range = util.enable_def_features(buf, crate)
      end
   else
      if crate_feature then
         line_range = util.disable_feature(buf, crate, crate_feature)
      else
         line_range = util.enable_feature(buf, crate, selected_feature)
      end
   end


   local c = {}
   for l in line_range:iter() do
      local line = vim.api.nvim_buf_get_lines(buf, l, l + 1, false)[1]
      line = toml.trim_comments(line)
      if crate.syntax == "table" then
         local cr = toml.parse_crate_table_vers(line)
         if cr then
            cr.vers.line = l
            table.insert(c, cr)
         end
         local cd = toml.parse_crate_table_def(line)
         if cd then
            cd.def.line = l
            table.insert(c, cd)
         end
         local cf = toml.parse_crate_table_feat(line)
         if cf then
            cf.feat.line = l
            table.insert(c, cf)
         end
      elseif crate.syntax == "plain" or crate.syntax == "inline_table" then
         local cf = toml.parse_crate(line)
         if cf and cf.vers then
            cf.vers.line = l
         end
         if cf and cf.def then
            cf.def.line = l
         end
         if cf and cf.feat then
            cf.feat.line = l
         end
         table.insert(c, cf)
      end
   end
   feat_ctx.crate = Crate.new(vim.tbl_extend("force", crate, unpack(c)))
   crate = feat_ctx.crate


   local features_text = {}
   local features_info = util.features_info(crate, features)
   if feature then
      for _, m in ipairs(feature.members) do
         local f = features:get_feat(m) or {
            name = m,
            members = {},
         }

         local hi_text = feature_text(features_info, f)
         table.insert(features_text, hi_text)
      end
   else
      for _, f in ipairs(features) do
         local hi_text = feature_text(features_info, f)
         table.insert(features_text, hi_text)
      end
   end

   vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
   for i, v in ipairs(features_text) do
      vim.api.nvim_buf_set_lines(M.buf, top_offset + i - 1, top_offset + i, false, { v.text })
      vim.api.nvim_buf_add_highlight(M.buf, M.namespace, v.hl, top_offset + i - 1, 0, -1)
   end
   vim.api.nvim_buf_set_option(M.buf, "modifiable", false)
end

function M.goto_feature(index)
   if not M.feat_ctx then return end
   local feat_ctx = M.feat_ctx

   local crate = feat_ctx.crate
   local version = feat_ctx.version
   local hist_index = feat_ctx.history_index
   local feature = feat_ctx.history[hist_index].feature

   local selected_feature = nil
   if feature then
      local m = feature.members[index]
      if m then
         selected_feature = version.features:get_feat(m)
      end
   else
      selected_feature = version.features[index]
   end
   if not selected_feature then return end

   M._open_feature_details(crate, version, selected_feature, {
      focus = true,
      update = true,
   })


   local current = feat_ctx.history[hist_index]
   current.line = index + top_offset

   feat_ctx.history_index = hist_index + 1
   hist_index = feat_ctx.history_index
   for i = hist_index, #feat_ctx.history, 1 do
      feat_ctx.history[i] = nil
   end

   feat_ctx.history[hist_index] = {
      feature = selected_feature,
      line = 3,
   }
end

function M.jump_back_feature(line)
   if not M.feat_ctx then return end
   local feat_ctx = M.feat_ctx

   local crate = feat_ctx.crate
   local version = feat_ctx.version
   local hist_index = feat_ctx.history_index

   if hist_index == 1 then
      M.hide()
      return
   end


   local current = feat_ctx.history[hist_index]
   current.line = line

   feat_ctx.history_index = hist_index - 1
   hist_index = feat_ctx.history_index

   if hist_index == 1 then
      M._open_features(crate, version, {
         focus = true,
         line = feat_ctx.history[1].line,
         update = true,
      })
   else
      local entry = feat_ctx.history[hist_index]
      if not entry then return end

      M._open_feature_details(crate, version, entry.feature, {
         focus = true,
         line = entry.line,
         update = true,
      })
   end
end

function M.jump_forward_feature(line)
   if not M.feat_ctx then return end
   local feat_ctx = M.feat_ctx

   local crate = feat_ctx.crate
   local version = feat_ctx.version
   local hist_index = feat_ctx.history_index

   if hist_index == #feat_ctx.history then
      return
   end


   local current = feat_ctx.history[hist_index]
   current.line = line

   feat_ctx.history_index = hist_index + 1
   hist_index = feat_ctx.history_index

   local entry = feat_ctx.history[hist_index]
   if not entry then return end

   M._open_feature_details(crate, version, entry.feature, {
      focus = true,
      line = entry.line,
      update = true,
   })
end


function M.open_deps(crate_name, version, opts)
   M.deps_ctx = {
      buf = util.current_buf(),
      history = {
         { crate_name = crate_name, version = version, line = opts and opts.line or 3 },
      },
      history_index = 1,
   }
   M._open_deps(crate_name, version, opts)
end

function M._open_deps(crate_name, version, opts)
   M.type = "dependencies"

   local deps = version.deps
   if not deps then return end

   local title = string.format(core.cfg.popup.text.title, crate_name .. " " .. version.num)
   local deps_width = 0
   local deps_text = {}

   for _, d in ipairs(deps) do
      local text, hl
      if d.opt then
         text = string.format(core.cfg.popup.text.optional, d.name)
         hl = core.cfg.popup.highlight.optional
      else
         text = string.format(core.cfg.popup.text.dependency, d.name)
         hl = core.cfg.popup.highlight.dependency
      end

      table.insert(deps_text, { text = text, hl = hl })
      deps_width = math.max(vim.fn.strdisplaywidth(text), deps_width)
   end

   local vers_width = 0
   if core.cfg.popup.show_dependency_version then
      for i, d in ipairs(deps_text) do
         local diff = deps_width - vim.fn.strdisplaywidth(d.text)
         local date = deps[i].vers.text
         d.text = d.text .. string.rep(" ", diff)
         d.suffix = string.format(core.cfg.popup.text.dependency_version, date)
         d.suffix_hl = core.cfg.popup.highlight.dependency_version

         vers_width = math.max(vim.fn.strdisplaywidth(d.suffix), vers_width)
      end
   end

   local width = win_width(title, deps_width + vers_width)
   local height = win_height(deps)

   if opts.update then
      update_win(width, height, title, deps_text, opts)
   else
      open_win(width, height, title, deps_text, opts, function()
         local goto_cmd = string.format(
         ":lua require('crates.popup').goto_dep(%s - %d)<cr>",
         "vim.api.nvim_win_get_cursor(0)[1]",
         top_offset)

         for _, k in ipairs(core.cfg.popup.keys.goto_item) do
            vim.api.nvim_buf_set_keymap(M.buf, "n", k, goto_cmd, { noremap = true, silent = true })
         end

         local jump_forward_cmd = string.format(
         ":lua require('crates.popup').jump_forward_dep(%s)<cr>",
         "vim.api.nvim_win_get_cursor(0)[1]")

         for _, k in ipairs(core.cfg.popup.keys.jump_forward) do
            vim.api.nvim_buf_set_keymap(M.buf, "n", k, jump_forward_cmd, { noremap = true, silent = true })
         end

         local jump_back_cmd = string.format(
         ":lua require('crates.popup').jump_back_dep(%s)<cr>",
         "vim.api.nvim_win_get_cursor(0)[1]")

         for _, k in ipairs(core.cfg.popup.keys.jump_back) do
            vim.api.nvim_buf_set_keymap(M.buf, "n", k, jump_back_cmd, { noremap = true, silent = true })
         end
      end)
   end
end

local function goto_dep(crate_name, version)
   if not M.deps_ctx then return end
   local deps_ctx = M.deps_ctx

   local hist_index = deps_ctx.history_index

   M._open_deps(crate_name, version, {
      focus = true,
      update = true,
   })

   deps_ctx.history_index = hist_index + 1
   hist_index = deps_ctx.history_index
   for i = hist_index, #deps_ctx.history, 1 do
      deps_ctx.history[i] = nil
   end


   deps_ctx.transaction = nil

   deps_ctx.history[hist_index] = {
      crate_name = crate_name,
      version = version,
      line = 3,
   }
end

local function show_loading_indicator()
   vim.api.nvim_buf_set_extmark(M.buf, M.namespace, 0, -1, {
      virt_text = { { core.cfg.popup.text.loading, core.cfg.popup.highlight.loading } },
      virt_text_pos = "right_align",
      hl_mode = "combine",
   })
end

local function hide_loading_indicator()
   if M.buf then
      vim.api.nvim_buf_clear_namespace(M.buf, M.namespace, 0, 1)
   end
end

local function fetch_deps(
   crate_name,
   versions,
   version,
   deps_ctx,
   transaction)

   if not api.is_fetching_deps(crate_name, version.num) then
      state.reload_deps(crate_name, versions, version)
   end
   api.add_deps_callback(crate_name, version.num, function(_deps, cancelled)
      hide_loading_indicator()
      if cancelled then return end


      if M.deps_ctx == deps_ctx and deps_ctx.transaction == transaction then
         goto_dep(crate_name, version)
      end
   end)
end

function M.goto_dep(index)
   if not M.deps_ctx then return end
   local deps_ctx = M.deps_ctx

   local hist_index = deps_ctx.history_index
   local hist_entry = deps_ctx.history[hist_index]
   local deps = hist_entry.version.deps

   if not deps or not deps[index] then return end
   local selected_dependency = deps[index]


   local current = deps_ctx.history[hist_index]
   current.line = index + top_offset

   local crate_name = selected_dependency.name
   local versions = core.vers_cache[crate_name]
   if versions then
      local m, p, y = util.get_newest(versions, false, selected_dependency.vers.reqs)
      local match = m or p or y

      if match.deps then
         goto_dep(crate_name, match)
      else
         local transaction = math.random()
         deps_ctx.transaction = transaction
         show_loading_indicator()
         fetch_deps(crate_name, versions, match, deps_ctx, transaction)
      end
   else
      local transaction = math.random()
      deps_ctx.transaction = transaction

      show_loading_indicator()

      if not api.is_fetching_vers(crate_name) then
         state.reload_crate(crate_name)
      end

      api.add_vers_callback(crate_name, function(versions, cancelled)
         if cancelled then
            hide_loading_indicator()
            return
         end

         local m, p, y = util.get_newest(versions, false, selected_dependency.vers.reqs)
         local match = m or p or y

         fetch_deps(crate_name, versions, match, deps_ctx, transaction)
      end)
   end
end

function M.jump_back_dep(line)
   if not M.deps_ctx then return end
   local deps_ctx = M.deps_ctx

   local hist_index = deps_ctx.history_index

   if hist_index == 1 then
      M.hide()
      return
   end


   local current = deps_ctx.history[hist_index]
   current.line = line

   deps_ctx.history_index = hist_index - 1
   hist_index = deps_ctx.history_index

   local entry = deps_ctx.history[hist_index]
   if not entry then return end


   deps_ctx.transaction = nil

   M._open_deps(entry.crate_name, entry.version, {
      focus = true,
      line = entry.line,
      update = true,
   })
end

function M.jump_forward_dep(line)
   if not M.deps_ctx then return end
   local deps_ctx = M.deps_ctx

   local hist_index = deps_ctx.history_index

   if hist_index == #deps_ctx.history then
      return
   end


   local current = deps_ctx.history[hist_index]
   current.line = line

   deps_ctx.history_index = hist_index + 1
   hist_index = deps_ctx.history_index

   local entry = deps_ctx.history[hist_index]
   if not entry then return end


   deps_ctx.transaction = nil

   M._open_deps(entry.crate_name, entry.version, {
      focus = true,
      line = entry.line,
      update = true,
   })
end

return M
