local Popup = {FeatureContext = {}, HistoryEntry = {}, WinOpts = {}, HighlightText = {}, LineCrateInfo = {}, }















































local HistoryEntry = Popup.HistoryEntry
local WinOpts = Popup.WinOpts
local HighlightText = Popup.HighlightText
local LineCrateInfo = Popup.LineCrateInfo
local core = require('crates.core')
local api = require('crates.api')
local Version = api.Version
local Feature = api.Feature
local toml = require('crates.toml')
local Crate = toml.Crate
local util = require('crates.util')
local FeatureInfo = util.FeatureInfo
local Range = require('crates.types').Range

local top_offset = 2

Popup.namespace = vim.api.nvim_create_namespace("crates.nvim.popup")

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
      if line == crate.feat.line then
         features_info()
      elseif line == crate.def.line then
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

function Popup.show()
   if Popup.win and vim.api.nvim_win_is_valid(Popup.win) then
      Popup.focus()
      return
   end

   local info = line_crate_info()
   if not info then return end

   if info.pref == "versions" then
      Popup.open_versions(info.crate, info.versions)
   elseif info.pref == "features" then
      Popup.open_features(info.crate, info.newest)
   elseif info.pref == "feature_details" then
      Popup.open_feature_details(info.crate, info.newest, info.feature)
   end
end

function Popup.show_versions()
   if Popup.win and vim.api.nvim_win_is_valid(Popup.win) then
      if Popup.type == "versions" then
         Popup.focus()
         return
      else
         Popup.hide()
      end
   end

   local info = line_crate_info()
   if not info then return end

   Popup.open_versions(info.crate, info.versions)
end

function Popup.show_features()
   if Popup.win and vim.api.nvim_win_is_valid(Popup.win) then
      if Popup.type == "features" then
         Popup.focus()
         return
      else
         Popup.hide()
      end
   end

   local info = line_crate_info()
   if not info then return end

   if info.pref == "features" then
      Popup.open_features(info.crate, info.newest)
   elseif info.pref == "feature_details" then
      Popup.open_feature_details(info.crate, info.newest, info.feature)
   elseif info.newest then
      Popup.open_features(info.crate, info.newest)
   end
end

function Popup.focus(line)
   if Popup.win and vim.api.nvim_win_is_valid(Popup.win) then
      vim.api.nvim_set_current_win(Popup.win)
      local l = math.min(line or 3, vim.api.nvim_buf_line_count(Popup.buf))
      vim.api.nvim_win_set_cursor(Popup.win, { l, 0 })
   end
end

function Popup.hide()
   if Popup.win and vim.api.nvim_win_is_valid(Popup.win) then
      vim.api.nvim_win_close(Popup.win, false)
   end
   Popup.win = nil

   if Popup.buf and vim.api.nvim_buf_is_valid(Popup.buf) then
      vim.api.nvim_buf_delete(Popup.buf, {})
   end
   Popup.buf = nil
   Popup.type = nil
end

local function create_win(width, height)
   local opts = {
      relative = "cursor",
      col = 0,
      row = 1,
      width = width,
      height = height,
      style = core.cfg.popup.style,
      border = core.cfg.popup.border,
   }
   Popup.win = vim.api.nvim_open_win(Popup.buf, false, opts)
end

local function open_win(width, height, title, text, opts, configure)
   Popup.buf = vim.api.nvim_create_buf(false, true)


   vim.api.nvim_buf_set_lines(Popup.buf, 0, 2, false, { title, "" })
   vim.api.nvim_buf_add_highlight(Popup.buf, Popup.namespace, core.cfg.popup.highlight.title, 0, 0, -1)

   for i, v in ipairs(text) do
      vim.api.nvim_buf_set_lines(Popup.buf, top_offset + i - 1, top_offset + i, false, { v.text })
      vim.api.nvim_buf_add_highlight(Popup.buf, Popup.namespace, v.hi, top_offset + i - 1, 0, -1)
   end

   vim.api.nvim_buf_set_option(Popup.buf, "modifiable", false)


   create_win(width, height)


   local hide_cmd = ":lua require('crates.popup').hide()<cr>"
   for _, k in ipairs(core.cfg.popup.keys.hide) do
      vim.api.nvim_buf_set_keymap(Popup.buf, "n", k, hide_cmd, { noremap = true, silent = true })
   end

   if configure then
      configure()
   end


   if opts and opts.focus or core.cfg.popup.autofocus then
      Popup.focus(opts and opts.line)
   end
end


function Popup.open_versions(crate, versions, opts)
   Popup.type = "versions"
   local title = string.format(core.cfg.popup.text.title, crate.name)
   local height = math.min(core.cfg.popup.max_height, #versions + top_offset)
   local width = 0
   local versions_text = {}

   for _, v in ipairs(versions) do
      local text, hi
      if v.yanked then
         text = string.format(core.cfg.popup.text.yanked, v.num)
         hi = core.cfg.popup.highlight.yanked
      elseif v.parsed.pre then
         text = string.format(core.cfg.popup.text.prerelease, v.num)
         hi = core.cfg.popup.highlight.prerelease
      else
         text = string.format(core.cfg.popup.text.version, v.num)
         hi = core.cfg.popup.highlight.version
      end


      table.insert(versions_text, { text = text, hi = hi })
      width = math.max(vim.fn.strdisplaywidth(text), width)
   end

   if core.cfg.popup.version_date then
      local orig_width = width

      for i, v in ipairs(versions_text) do
         local diff = orig_width - vim.fn.strdisplaywidth(v.text)
         local date = versions[i].created:display(core.cfg.date_format)
         local date_text = string.format(core.cfg.popup.text.date, date)
         v.text = v.text .. string.rep(" ", diff) .. date_text

         width = math.max(vim.fn.strdisplaywidth(v.text), orig_width)
      end
   end

   width = math.max(width, core.cfg.popup.min_width, vim.fn.strdisplaywidth(title))


   open_win(width, height, title, versions_text, opts, function()
      local select_cmd = string.format(
      ":lua require('crates.popup').select_version(%d, '%s', %s - %d)<cr>",
      util.current_buf(),
      crate.name,
      "vim.api.nvim_win_get_cursor(0)[1]",
      top_offset)

      for _, k in ipairs(core.cfg.popup.keys.select) do
         vim.api.nvim_buf_set_keymap(Popup.buf, "n", k, select_cmd, { noremap = true, silent = true })
      end

      local select_alt_cmd = string.format(
      ":lua require('crates.popup').select_version(%d, '%s', %s - %d, true)<cr>",
      util.current_buf(),
      crate.name,
      "vim.api.nvim_win_get_cursor(0)[1]",
      top_offset)

      for _, k in ipairs(core.cfg.popup.keys.select_alt) do
         vim.api.nvim_buf_set_keymap(Popup.buf, "n", k, select_alt_cmd, { noremap = true, silent = true })
      end

      local copy_cmd = string.format(
      ":lua require('crates.popup').copy_version('%s', %s - %d, true)<cr>",
      crate.name,
      "vim.api.nvim_win_get_cursor(0)[1]",
      top_offset)

      for _, k in ipairs(core.cfg.popup.keys.copy_version) do
         vim.api.nvim_buf_set_keymap(Popup.buf, "n", k, copy_cmd, { noremap = true, silent = true })
      end
   end)
end

function Popup.select_version(buf, name, index, alt)
   local crates = core.crate_cache[buf]
   if not crates then return end

   local crate = crates[name]
   if not crate then return end

   local versions = core.vers_cache[name]
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

function Popup.copy_version(name, index)
   local versions = core.vers_cache[name]
   if not versions then return end

   if index <= 0 or index > #versions then
      return
   end
   local text = versions[index].num

   vim.fn.setreg(core.cfg.popup.copy_register, text)
end


local function feature_text(features_info, feature)
   local text, hi
   local info = features_info[feature.name]
   if info.enabled then
      text = string.format(core.cfg.popup.text.enabled, feature.name)
      hi = core.cfg.popup.highlight.enabled
   elseif info.transitive then
      text = string.format(core.cfg.popup.text.transitive, feature.name)
      hi = core.cfg.popup.highlight.transitive
   else
      text = string.format(core.cfg.popup.text.feature, feature.name)
      hi = core.cfg.popup.highlight.feature
   end
   return { text = text, hi = hi }
end

local function open_feat_win(width, height, title, text, opts)
   open_win(width, height, title, text, opts, function()
      local toggle_cmd = string.format(
      ":lua require('crates.popup').toggle_feature(%s - %d)<cr>",
      "vim.api.nvim_win_get_cursor(0)[1]",
      top_offset)

      for _, k in ipairs(core.cfg.popup.keys.toggle_feature) do
         vim.api.nvim_buf_set_keymap(Popup.buf, "n", k, toggle_cmd, { noremap = true, silent = true })
      end

      local goto_cmd = string.format(
      ":lua require('crates.popup').goto_feature(%s - %d)<cr>",
      "vim.api.nvim_win_get_cursor(0)[1]",
      top_offset)

      for _, k in ipairs(core.cfg.popup.keys.goto_feature) do
         vim.api.nvim_buf_set_keymap(Popup.buf, "n", k, goto_cmd, { noremap = true, silent = true })
      end

      local jump_forward_cmd = string.format(
      ":lua require('crates.popup').jump_forward_feature(%s)<cr>",
      "vim.api.nvim_win_get_cursor(0)[1]")

      for _, k in ipairs(core.cfg.popup.keys.jump_forward_feature) do
         vim.api.nvim_buf_set_keymap(Popup.buf, "n", k, jump_forward_cmd, { noremap = true, silent = true })
      end

      local jump_back_cmd = string.format(
      ":lua require('crates.popup').jump_back_feature(%s)<cr>",
      "vim.api.nvim_win_get_cursor(0)[1]")

      for _, k in ipairs(core.cfg.popup.keys.jump_back_feature) do
         vim.api.nvim_buf_set_keymap(Popup.buf, "n", k, jump_back_cmd, { noremap = true, silent = true })
      end
   end)
end

function Popup.open_features(crate, version, opts)
   Popup.type = "features"
   Popup.feat_ctx = {
      buf = util.current_buf(),
      crate = crate,
      version = version,
      history = {
         { feature = nil, line = opts and opts.line or 3 },
      },
      history_index = 1,
   }
   Popup._open_features(crate, version, opts)
end

function Popup._open_features(crate, version, opts)
   local features = version.features
   local title = string.format(core.cfg.popup.text.title, crate.name .. " " .. version.num)
   local height = math.min(core.cfg.popup.max_height, #features + top_offset)
   local width = math.max(core.cfg.popup.min_width, title:len())
   local features_text = {}

   local features_info = util.features_info(crate, features)
   for _, f in ipairs(features) do
      local hi_text = feature_text(features_info, f)
      table.insert(features_text, hi_text)
      width = math.max(hi_text.text:len(), width)
   end

   open_feat_win(width, height, title, features_text, opts)
end

function Popup.open_feature_details(crate, version, feature, opts)
   Popup.type = "features"
   Popup.feat_ctx = {
      buf = util.current_buf(),
      crate = crate,
      version = version,
      history = {
         { feature = nil, line = 3 },
         { feature = feature, line = opts and opts.line or 3 },
      },
      history_index = 2,
   }
   Popup._open_feature_details(crate, version, feature, opts)
end

function Popup._open_feature_details(crate, version, feature, opts)
   local features = version.features
   local members = feature.members
   local title = string.format(core.cfg.popup.text.title, crate.name .. " " .. version.num .. " " .. feature.name)
   local height = math.min(core.cfg.popup.max_height, #members + top_offset)
   local width = math.max(core.cfg.popup.min_width, title:len())
   local features_text = {}

   local features_info = util.features_info(crate, features)
   for _, m in ipairs(members) do
      local f = features:get_feat(m) or {
         name = m,
         members = {},
      }

      local hi_text = feature_text(features_info, f)
      table.insert(features_text, hi_text)
      width = math.max(hi_text.text:len(), width)
   end

   open_feat_win(width, height, title, features_text, opts)
end

function Popup.toggle_feature(index)
   if not Popup.feat_ctx then return end

   local buf = Popup.feat_ctx.buf
   local crate = Popup.feat_ctx.crate
   local version = Popup.feat_ctx.version
   local features = version.features
   local hist_index = Popup.feat_ctx.history_index
   local feature = Popup.feat_ctx.history[hist_index].feature

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
   Popup.feat_ctx.crate = Crate.new(vim.tbl_extend("force", crate, unpack(c)))
   crate = Popup.feat_ctx.crate


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

   vim.api.nvim_buf_set_option(Popup.buf, "modifiable", true)
   for i, v in ipairs(features_text) do
      vim.api.nvim_buf_set_lines(Popup.buf, top_offset + i - 1, top_offset + i, false, { v.text })
      vim.api.nvim_buf_add_highlight(Popup.buf, Popup.namespace, v.hi, top_offset + i - 1, 0, -1)
   end
   vim.api.nvim_buf_set_option(Popup.buf, "modifiable", false)
end

function Popup.goto_feature(index)
   if not Popup.feat_ctx then return end

   local crate = Popup.feat_ctx.crate
   local version = Popup.feat_ctx.version
   local hist_index = Popup.feat_ctx.history_index
   local feature = Popup.feat_ctx.history[hist_index].feature

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

   Popup.hide()
   Popup._open_feature_details(crate, version, selected_feature, { focus = true })


   local current = Popup.feat_ctx.history[hist_index]
   current.line = index + top_offset

   Popup.feat_ctx.history_index = hist_index + 1
   hist_index = Popup.feat_ctx.history_index
   for i = hist_index, #Popup.feat_ctx.history, 1 do
      Popup.feat_ctx.history[i] = nil
   end

   Popup.feat_ctx.history[hist_index] = {
      feature = selected_feature,
      line = 3,
   }
end

function Popup.jump_back_feature(line)
   if not Popup.feat_ctx then return end

   local crate = Popup.feat_ctx.crate
   local version = Popup.feat_ctx.version
   local hist_index = Popup.feat_ctx.history_index

   if hist_index == 1 then
      Popup.hide()
      return
   end


   local current = Popup.feat_ctx.history[hist_index]
   current.line = line

   Popup.feat_ctx.history_index = hist_index - 1
   hist_index = Popup.feat_ctx.history_index

   if hist_index == 1 then
      Popup.hide()
      Popup._open_features(crate, version, {
         focus = true,
         line = Popup.feat_ctx.history[1].line,
      })
   else
      local entry = Popup.feat_ctx.history[hist_index]
      if not entry then return end

      Popup.hide()
      Popup._open_feature_details(crate, version, entry.feature, {
         focus = true,
         line = entry.line,
      })
   end
end

function Popup.jump_forward_feature(line)
   if not Popup.feat_ctx then return end

   local crate = Popup.feat_ctx.crate
   local version = Popup.feat_ctx.version
   local hist_index = Popup.feat_ctx.history_index

   if hist_index == #Popup.feat_ctx.history then
      return
   end


   local current = Popup.feat_ctx.history[hist_index]
   current.line = line

   Popup.feat_ctx.history_index = hist_index + 1
   hist_index = Popup.feat_ctx.history_index

   local entry = Popup.feat_ctx.history[hist_index]
   if not entry then return end

   Popup.hide()
   Popup._open_feature_details(crate, version, entry.feature, {
      focus = true,
      line = entry.line,
   })
end

return Popup
