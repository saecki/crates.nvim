local M = {FeatureContext = {}, FeatHistoryEntry = {}, }

















local FeatureContext = M.FeatureContext
local FeatHistoryEntry = M.FeatHistoryEntry
local popup = require("crates.popup.common")
local HighlightText = popup.HighlightText
local WinOpts = popup.WinOpts
local state = require("crates.state")
local toml = require("crates.toml")
local types = require("crates.types")
local Feature = types.Feature
local Range = types.Range
local Version = types.Version
local util = require("crates.util")
local FeatureInfo = util.FeatureInfo

local function feature_text(features_info, feature)
   local t = {}
   local info = features_info[feature.name]
   if info.enabled then
      t.text = string.format(state.cfg.popup.text.enabled, feature.name)
      t.hl = state.cfg.popup.highlight.enabled
   elseif info.transitive then
      t.text = string.format(state.cfg.popup.text.transitive, feature.name)
      t.hl = state.cfg.popup.highlight.transitive
   else
      t.text = string.format(state.cfg.popup.text.feature, feature.name)
      t.hl = state.cfg.popup.highlight.feature
   end
   return { t }
end

local function toggle_feature(ctx, line)
   local index = popup.item_index(line)
   local features = ctx.version.features
   local entry = ctx.history[ctx.hist_idx]

   local selected_feature
   if entry.feature then
      local m = entry.feature.members[index]
      if m then
         selected_feature = features:get_feat(m)
      end
   else
      selected_feature = features[index]
   end
   if not selected_feature then return end

   local line_range
   local crate_feature = ctx.crate:get_feat(selected_feature.name)
   if selected_feature.name == "default" then
      if crate_feature ~= nil or ctx.crate:is_def_enabled() then
         line_range = util.disable_def_features(ctx.buf, ctx.crate, crate_feature)
      else
         line_range = util.enable_def_features(ctx.buf, ctx.crate)
      end
   else
      if crate_feature then
         line_range = util.disable_feature(ctx.buf, ctx.crate, crate_feature)
      else
         line_range = util.enable_feature(ctx.buf, ctx.crate, selected_feature)
      end
   end


   local c = {}
   for l in line_range:iter() do
      local text = vim.api.nvim_buf_get_lines(ctx.buf, l, l + 1, false)[1]
      text = toml.trim_comments(text)
      if ctx.crate.syntax == "table" then
         local cr = toml.parse_crate_table_vers(text)
         if cr then
            cr.vers.line = l
            table.insert(c, cr)
         end
         local cd = toml.parse_crate_table_def(text)
         if cd then
            cd.def.line = l
            table.insert(c, cd)
         end
         local cf = toml.parse_crate_table_feat(text)
         if cf then
            cf.feat.line = l
            table.insert(c, cf)
         end
      elseif ctx.crate.syntax == "plain" or ctx.crate.syntax == "inline_table" then
         local cf = toml.parse_crate(text)
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
   ctx.crate = toml.Crate.new(vim.tbl_extend("force", ctx.crate, unpack(c)))


   local features_text = {}
   local features_info = util.features_info(ctx.crate, features)
   if entry.feature then
      for _, m in ipairs(entry.feature.members) do
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

   popup.update_buf_body(features_text)
end

local function goto_feature(ctx, line)
   local index = popup.item_index(line)
   local crate = ctx.crate
   local version = ctx.version
   local feature = ctx.history[ctx.hist_idx].feature

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

   M.open_feature_details(ctx, crate, version, selected_feature, {
      focus = true,
      update = true,
   })


   local current = ctx.history[ctx.hist_idx]
   current.line = line

   ctx.hist_idx = ctx.hist_idx + 1
   for i = ctx.hist_idx, #ctx.history, 1 do
      ctx.history[i] = nil
   end

   ctx.history[ctx.hist_idx] = {
      feature = selected_feature,
      line = 2,
   }
end

local function jump_back_feature(ctx, line)
   local crate = ctx.crate
   local version = ctx.version

   if ctx.hist_idx == 1 then
      popup.hide()
      return
   end


   local current = ctx.history[ctx.hist_idx]
   current.line = line

   ctx.hist_idx = ctx.hist_idx - 1

   if ctx.hist_idx == 1 then
      M.open_features(ctx, crate, version, {
         focus = true,
         line = ctx.history[1].line,
         update = true,
      })
   else
      local entry = ctx.history[ctx.hist_idx]
      if not entry then return end

      M.open_feature_details(ctx, crate, version, entry.feature, {
         focus = true,
         line = entry.line,
         update = true,
      })
   end
end

local function jump_forward_feature(ctx, line)
   local crate = ctx.crate
   local version = ctx.version

   if ctx.hist_idx == #ctx.history then
      return
   end


   local current = ctx.history[ctx.hist_idx]
   current.line = line

   ctx.hist_idx = ctx.hist_idx + 1

   local entry = ctx.history[ctx.hist_idx]
   if not entry then return end

   M.open_feature_details(ctx, crate, version, entry.feature, {
      focus = true,
      line = entry.line,
      update = true,
   })
end

local function config_feat_win(ctx)
   return function(_win, buf)
      for _, k in ipairs(state.cfg.popup.keys.toggle_feature) do
         vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
            callback = function()
               local line = util.cursor_pos()
               toggle_feature(ctx, line)
            end,
            noremap = true,
            silent = true,
            desc = "Toggle feature",
         })
      end

      for _, k in ipairs(state.cfg.popup.keys.goto_item) do
         vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
            callback = function()
               local line = util.cursor_pos()
               goto_feature(ctx, line)
            end,
            noremap = true,
            silent = true,
            desc = "Goto feature",
         })
      end

      for _, k in ipairs(state.cfg.popup.keys.jump_forward) do
         vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
            callback = function()
               local line = util.cursor_pos()
               jump_forward_feature(ctx, line)
            end,
            noremap = true,
            silent = true,
            desc = "Jump forward",
         })
      end

      for _, k in ipairs(state.cfg.popup.keys.jump_back) do
         vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
            callback = function()
               local line = util.cursor_pos()
               jump_back_feature(ctx, line)
            end,
            noremap = true,
            silent = true,
            desc = "Jump back",
         })
      end
   end
end

function M.open_features(ctx, crate, version, opts)
   popup.type = "features"

   local features = version.features
   local title = string.format(state.cfg.popup.text.title, crate.name .. " " .. version.num)
   local feat_width = 0
   local features_text = {}

   local features_info = util.features_info(crate, features)
   for _, f in ipairs(features) do
      local hl_text = feature_text(features_info, f)
      table.insert(features_text, hl_text)
      local w = 0
      for _, t in ipairs(hl_text) do
         w = w + vim.fn.strdisplaywidth(t.text)
      end
      feat_width = math.max(w, feat_width)
   end

   local width = popup.win_width(title, feat_width)
   local height = popup.win_height(features)

   if opts.update then
      popup.update_win(width, height, title, features_text, opts)
   else
      popup.open_win(width, height, title, features_text, opts, config_feat_win(ctx))
   end
end

function M.open_feature_details(ctx, crate, version, feature, opts)
   popup.type = "features"

   local features = version.features
   local members = feature.members
   local title = string.format(state.cfg.popup.text.title, crate.name .. " " .. version.num .. " " .. feature.name)
   local feat_width = 0
   local features_text = {}

   local features_info = util.features_info(crate, features)
   for _, m in ipairs(members) do
      local f = features:get_feat(m) or {
         name = m,
         members = {},
      }

      local hl_text = feature_text(features_info, f)
      table.insert(features_text, hl_text)
      local w = 0
      for _, t in ipairs(hl_text) do
         w = w + vim.fn.strdisplaywidth(t.text)
      end
      feat_width = math.max(w, feat_width)
   end

   local width = popup.win_width(title, feat_width)
   local height = popup.win_height(members)

   if opts.update then
      popup.update_win(width, height, title, features_text, opts)
   else
      popup.open_win(width, height, title, features_text, opts, config_feat_win(ctx))
   end
end

function M.open(crate, version, opts)
   local ctx = {
      buf = util.current_buf(),
      crate = crate,
      version = version,
      history = {
         { feature = nil, line = opts and opts.line or 3 },
      },
      hist_idx = 1,
   }
   M.open_features(ctx, crate, version, opts)
end

function M.open_details(crate, version, feature, opts)
   local ctx = {
      buf = util.current_buf(),
      crate = crate,
      version = version,
      history = {
         { feature = nil, line = 2 },
         { feature = feature, line = opts and opts.line or 3 },
      },
      hist_idx = 2,
   }
   M.open_feature_details(ctx, crate, version, feature, opts)
end

return M
