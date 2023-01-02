local M = {DepsContext = {}, DepsHistoryEntry = {}, }
















local DepsContext = M.DepsContext
local api = require("crates.api")
local async = require("crates.async")
local core = require("crates.core")
local popup = require("crates.popup.common")
local HighlightText = popup.HighlightText
local WinOpts = popup.WinOpts
local state = require("crates.state")
local types = require("crates.types")
local Dependency = types.Dependency
local Version = types.Version
local util = require("crates.util")

local goto_dep = async.wrap(function(ctx, line)
   local hist_entry = ctx.history[ctx.hist_idx]

   local selected_dependency = hist_entry.line_mapping[line]
   if not selected_dependency then return end


   hist_entry.line = line

   local transaction = math.random()
   popup.transaction = transaction

   local crate_name = selected_dependency.name
   local crate = state.api_cache.crates[crate_name]

   if not crate then
      popup.show_loading_indicator()

      if not api.is_fetching_crate(crate_name) then
         core.reload_crate(crate_name)
      end

      local cancelled
      crate, cancelled = api.await_crate(crate_name)

      popup.hide_loading_indicator(transaction)
      if cancelled then return end
   end


   if popup.transaction ~= transaction then
      return
   end

   local m, p, y = util.get_newest(crate.versions, false, selected_dependency.vers.reqs)
   local version = m or p or y

   if not version.deps then
      popup.show_loading_indicator()

      if not api.is_fetching_deps(crate_name, version.num) then
         core.reload_deps(crate_name, crate.versions, version)
      end
      local _, cancelled = api.await_deps(crate_name, version.num)

      popup.hide_loading_indicator(transaction)
      if cancelled then return end
   end


   if popup.transaction ~= transaction then
      return
   end

   ctx.hist_idx = ctx.hist_idx + 1
   for i = ctx.hist_idx, #ctx.history, 1 do
      ctx.history[i] = nil
   end

   ctx.history[ctx.hist_idx] = {
      crate_name = crate_name,
      version = version,
      line = 2,
   }

   M.open_deps(ctx, crate_name, version, {
      focus = true,
      update = true,
   })
end)

local function jump_back_dep(ctx, line)
   if ctx.hist_idx == 1 then
      popup.hide()
      return
   end


   local current = ctx.history[ctx.hist_idx]
   current.line = line

   ctx.hist_idx = ctx.hist_idx - 1

   local entry = ctx.history[ctx.hist_idx]
   if not entry then return end

   M.open_deps(ctx, entry.crate_name, entry.version, {
      focus = true,
      line = entry.line,
      update = true,
   })
end

local function jump_forward_dep(ctx, line)
   if ctx.hist_idx == #ctx.history then
      return
   end


   local current = ctx.history[ctx.hist_idx]
   current.line = line

   ctx.hist_idx = ctx.hist_idx + 1

   local entry = ctx.history[ctx.hist_idx]
   if not entry then return end

   M.open_deps(ctx, entry.crate_name, entry.version, {
      focus = true,
      line = entry.line,
      update = true,
   })
end

function M.open_deps(ctx, crate_name, version, opts)
   popup.type = "dependencies"

   popup.omit_loading_transaction()

   local deps = version.deps
   if not deps then return end

   local title = string.format(state.cfg.popup.text.title, crate_name .. " " .. version.num)
   local deps_width = 0
   local deps_text_index = {}




   local normal_deps_text = {}
   local build_deps_text = {}
   local dev_deps_text = {}

   for _, d in ipairs(deps) do
      local t = {}
      if d.opt then
         t.text = string.format(state.cfg.popup.text.optional, d.name)
         t.hl = state.cfg.popup.highlight.optional
      else
         t.text = string.format(state.cfg.popup.text.dependency, d.name)
         t.hl = state.cfg.popup.highlight.dependency
      end

      local line = { t, dep = d }
      if d.kind == "normal" then
         table.insert(normal_deps_text, line)
      elseif d.kind == "build" then
         table.insert(build_deps_text, line)
      elseif d.kind == "dev" then
         table.insert(dev_deps_text, line)
      end
      table.insert(deps_text_index, line)
      deps_width = math.max(vim.fn.strdisplaywidth(t.text), deps_width)
   end

   local vers_width = 0
   if state.cfg.popup.show_dependency_version then
      for i, line in ipairs(deps_text_index) do
         local dep_text = line[1]
         local diff = deps_width - vim.fn.strdisplaywidth(dep_text.text)
         local vers = deps[i].vers.text
         dep_text.text = dep_text.text .. string.rep(" ", diff)

         local vers_text = {
            text = string.format(state.cfg.popup.text.dependency_version, vers),
            hl = state.cfg.popup.highlight.dependency_version,
         }
         table.insert(line, vers_text)

         vers_width = math.max(vim.fn.strdisplaywidth(vers_text.text), vers_width)
      end
   end

   local deps_text = {}
   local line_mapping = {}
   local line_idx = popup.TOP_OFFSET
   if #normal_deps_text > 0 then
      table.insert(deps_text, { { text = state.cfg.popup.text.normal_dependencies_title, hl = state.cfg.popup.highlight.normal_dependencies_title } })
      line_idx = line_idx + 1

      for _, t in ipairs(normal_deps_text) do
         table.insert(deps_text, t)
         line_mapping[line_idx] = t.dep
         line_idx = line_idx + 1
      end
   end
   if #build_deps_text > 0 then
      if #deps_text > 0 then
         table.insert(deps_text, {})
         line_idx = line_idx + 1
      end
      table.insert(deps_text, { { text = state.cfg.popup.text.build_dependencies_title, hl = state.cfg.popup.highlight.build_dependencies_title } })
      line_idx = line_idx + 1

      for _, t in ipairs(build_deps_text) do
         table.insert(deps_text, t)
         line_mapping[line_idx] = t.dep
         line_idx = line_idx + 1
      end
   end
   if #dev_deps_text > 0 then
      if #deps_text > 0 then
         table.insert(deps_text, {})
         line_idx = line_idx + 1
      end
      table.insert(deps_text, { { text = state.cfg.popup.text.dev_dependencies_title, hl = state.cfg.popup.highlight.dev_dependencies_title } })
      line_idx = line_idx + 1

      for _, t in ipairs(dev_deps_text) do
         table.insert(deps_text, t)
         line_mapping[line_idx] = t.dep
         line_idx = line_idx + 1
      end
   end

   ctx.history[ctx.hist_idx].line_mapping = line_mapping

   local width = popup.win_width(title, deps_width + vers_width)
   local height = popup.win_height(deps_text)

   if opts.update then
      popup.update_win(width, height, title, deps_text, opts)
   else
      popup.open_win(width, height, title, deps_text, opts, function(_win, buf)
         for _, k in ipairs(state.cfg.popup.keys.goto_item) do
            vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
               callback = function()
                  local line = util.cursor_pos()
                  goto_dep(ctx, line)
               end,
               noremap = true,
               silent = true,
               desc = "Goto dependency",
            })
         end

         for _, k in ipairs(state.cfg.popup.keys.jump_forward) do
            vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
               callback = function()
                  local line = util.cursor_pos()
                  jump_forward_dep(ctx, line)
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
                  jump_back_dep(ctx, line)
               end,
               noremap = true,
               silent = true,
               desc = "Jump back",
            })
         end
      end)
   end
end

function M.open(crate_name, version, opts)
   local ctx = {
      buf = util.current_buf(),
      history = {
         { crate_name = crate_name, version = version, line = opts and opts.line or 2 },
      },
      hist_idx = 1,
   }
   M.open_deps(ctx, crate_name, version, opts)
end

return M
