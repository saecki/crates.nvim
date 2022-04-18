local M = {LineCrateInfo = {}, }















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
local Range = require("crates.types").Range
local popup = require("crates.popup.common")
local Type = popup.Type
local WinOpts = popup.WinOpts
local HighlightText = popup.HighlightText
local DepsContext = popup.DepsContext
local versions_popup = require("crates.popup.versions")
local features_popup = require("crates.popup.features")

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
   if popup.win and vim.api.nvim_win_is_valid(popup.win) then
      popup.focus()
      return
   end

   local info = line_crate_info()
   if not info then return end

   if info.pref == "versions" then
      versions_popup.open(info.crate, info.versions)
   elseif info.pref == "features" then
      features_popup.open(info.crate, info.newest, {})
   elseif info.pref == "feature_details" then
      features_popup.open_details(info.crate, info.newest, info.feature, {})
   elseif info.pref == "dependencies" then
      M.open_deps(info.crate.name, info.newest, {})
   end
end

function M.focus()
   popup.focus()
end

function M.hide()
   popup.hide()
end

function M.show_versions()
   if popup.win and vim.api.nvim_win_is_valid(popup.win) then
      if popup.type == "versions" then
         popup.focus()
         return
      else
         popup.hide()
      end
   end

   local info = line_crate_info()
   if not info then return end

   versions_popup.open(info.crate, info.versions)
end

function M.show_features()
   if popup.win and vim.api.nvim_win_is_valid(popup.win) then
      if popup.type == "features" then
         popup.focus()
         return
      else
         popup.hide()
      end
   end

   local info = line_crate_info()
   if not info then return end

   if info.pref == "features" then
      features_popup.open(info.crate, info.newest, {})
   elseif info.pref == "feature_details" then
      features_popup.open_details(info.crate, info.newest, info.feature, {})
   elseif info.newest then
      features_popup.open(info.crate, info.newest, {})
   end
end

function M.show_dependencies()
   if popup.win and vim.api.nvim_win_is_valid(popup.win) then
      if popup.type == "dependencies" then
         popup.focus()
         return
      else
         popup.hide()
      end
   end

   local info = line_crate_info()
   if not info then return end

   M.open_deps(info.crate.name, info.newest, {})
end




function M.open_deps(crate_name, version, opts)
   popup.deps_ctx = {
      buf = util.current_buf(),
      history = {
         { crate_name = crate_name, version = version, line = opts and opts.line or 3 },
      },
      history_index = 1,
   }
   M._open_deps(crate_name, version, opts)
end

function M._open_deps(crate_name, version, opts)
   popup.type = "dependencies"

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

   local width = popup.win_width(title, deps_width + vers_width)
   local height = popup.win_height(deps)

   if opts.update then
      popup.update_win(width, height, title, deps_text, opts)
   else
      popup.open_win(width, height, title, deps_text, opts, function()
         for _, k in ipairs(core.cfg.popup.keys.goto_item) do
            vim.api.nvim_buf_set_keymap(popup.buf, "n", k, "", {
               callback = function()
                  M.goto_dep(vim.api.nvim_win_get_cursor(0)[1] - popup.TOP_OFFSET)
               end,
               noremap = true,
               silent = true,
               desc = "Goto dependency",
            })
         end

         for _, k in ipairs(core.cfg.popup.keys.jump_forward) do
            vim.api.nvim_buf_set_keymap(popup.buf, "n", k, "", {
               callback = function()
                  M.jump_forward_dep(vim.api.nvim_win_get_cursor(0)[1])
               end,
               noremap = true,
               silent = true,
               desc = "Jump forward",
            })
         end

         for _, k in ipairs(core.cfg.popup.keys.jump_back) do
            vim.api.nvim_buf_set_keymap(popup.buf, "n", k, "", {
               callback = function()
                  M.jump_back_dep(vim.api.nvim_win_get_cursor(0)[1])
               end,
               noremap = true,
               silent = true,
               desc = "Jump back",
            })
         end
      end)
   end
end

local function goto_dep(crate_name, version)
   if not popup.deps_ctx then return end
   local deps_ctx = popup.deps_ctx

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
   vim.api.nvim_buf_set_extmark(popup.buf, popup.NAMESPACE, 0, -1, {
      virt_text = { { core.cfg.popup.text.loading, core.cfg.popup.highlight.loading } },
      virt_text_pos = "right_align",
      hl_mode = "combine",
   })
end

local function hide_loading_indicator()
   if popup.buf then
      vim.api.nvim_buf_clear_namespace(popup.buf, popup.NAMESPACE, 0, 1)
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


      if popup.deps_ctx == deps_ctx and deps_ctx.transaction == transaction then
         goto_dep(crate_name, version)
      end
   end)
end

function M.goto_dep(index)
   local deps_ctx = popup.deps_ctx
   if not deps_ctx then return end

   local hist_index = deps_ctx.history_index
   local hist_entry = deps_ctx.history[hist_index]
   local deps = hist_entry.version.deps

   if not deps or not deps[index] then return end
   local selected_dependency = deps[index]


   local current = deps_ctx.history[hist_index]
   current.line = index + popup.TOP_OFFSET

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
   local deps_ctx = popup.deps_ctx
   if not deps_ctx then return end

   local hist_index = deps_ctx.history_index

   if hist_index == 1 then
      popup.hide()
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
   local deps_ctx = popup.deps_ctx
   if not deps_ctx then return end

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
