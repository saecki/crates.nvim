local M = {DepsContext = {}, DepsHistoryEntry = {}, }















local DepsContext = M.DepsContext
local api = require("crates.api")
local Dependency = api.Dependency
local Version = api.Version
local async = require("crates.async")
local core = require("crates.core")
local popup = require("crates.popup.common")
local HighlightText = popup.HighlightText
local WinOpts = popup.WinOpts
local state = require("crates.state")
local util = require("crates.util")

local goto_dep = async.wrap(function(ctx, line)
   local index = line - popup.TOP_OFFSET
   local hist_entry = ctx.history[ctx.hist_idx]
   local deps = hist_entry.version.deps

   if not deps or not deps[index] then return end
   local selected_dependency = deps[index]


   hist_entry.line = line

   local transaction = math.random()
   popup.transaction = transaction

   local crate_name = selected_dependency.name
   local versions = core.vers_cache[crate_name]

   if not versions then
      popup.show_loading_indicator()

      if not api.is_fetching_vers(crate_name) then
         state.reload_crate(crate_name)
      end

      local cancelled
      versions, cancelled = api.await_vers(crate_name)

      popup.hide_loading_indicator(transaction)
      if cancelled then return end
   end


   if popup.transaction ~= transaction then
      return
   end

   local m, p, y = util.get_newest(versions, false, selected_dependency.vers.reqs)
   local version = m or p or y

   if not version.deps then
      popup.show_loading_indicator()

      if not api.is_fetching_deps(crate_name, version.num) then
         state.reload_deps(crate_name, versions, version)
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
      line = 3,
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
      popup.open_win(width, height, title, deps_text, opts, function(_win, buf)
         for _, k in ipairs(core.cfg.popup.keys.goto_item) do
            vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
               callback = function()
                  goto_dep(ctx, vim.api.nvim_win_get_cursor(0)[1])
               end,
               noremap = true,
               silent = true,
               desc = "Goto dependency",
            })
         end

         for _, k in ipairs(core.cfg.popup.keys.jump_forward) do
            vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
               callback = function()
                  jump_forward_dep(ctx, vim.api.nvim_win_get_cursor(0)[1])
               end,
               noremap = true,
               silent = true,
               desc = "Jump forward",
            })
         end

         for _, k in ipairs(core.cfg.popup.keys.jump_back) do
            vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
               callback = function()
                  jump_back_dep(ctx, vim.api.nvim_win_get_cursor(0)[1])
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
         { crate_name = crate_name, version = version, line = opts and opts.line or 3 },
      },
      hist_idx = 1,
   }
   M.open_deps(ctx, crate_name, version, opts)
end

return M
