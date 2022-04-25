local M = {CompletionList = {}, CompletionItem = {}, }
















local CompletionItem = M.CompletionItem
local CompletionList = M.CompletionList

local api = require("crates.api")
local async = require("crates.async")
local state = require("crates.state")
local toml = require("crates.toml")
local Crate = toml.Crate
local CrateFeature = toml.CrateFeature
local types = require("crates.types")
local Range = types.Range
local Version = types.Version
local util = require("crates.util")

local VALUE_KIND = 12

local function complete_versions(crate, versions)
   local items = {}

   for i, v in ipairs(versions) do
      local r = {
         label = v.num,
         kind = VALUE_KIND,
         sortText = string.format("%04d", i),
      }
      if state.cfg.src.insert_closing_quote then
         if crate.vers and not crate.vers.quote.e then
            r.insertText = v.num .. crate.vers.quote.s
         end
      end
      if v.yanked then
         r.deprecated = true
         r.documentation = state.cfg.src.text.yanked
      elseif v.parsed.pre then
         r.documentation = state.cfg.src.text.prerelease
      end

      table.insert(items, r)
   end

   return {
      isIncomplete = false,
      items = items,
   }
end

local function complete_features(crate, cf, versions)
   local avoid_pre = state.cfg.avoid_prerelease and not crate:vers_is_pre()
   local newest = util.get_newest(versions, avoid_pre, crate:vers_reqs())

   if not newest then
      return {
         isIncomplete = false,
         items = {},
      }
   end

   local items = {}
   for _, f in ipairs(newest.features) do
      local crate_feat = crate:get_feat(f.name)
      if not crate_feat then
         local r = {
            label = f.name,
            kind = VALUE_KIND,
            sortText = f.name,
            documentation = table.concat(f.members, "\n"),
         }
         if state.cfg.src.insert_closing_quote then
            if not cf.quote.e then
               r.insertText = f.name .. cf.quote.s
            end
         end

         table.insert(items, r)
      end
   end

   return {
      isIncomplete = not newest.deps,
      items = items,
   }
end

local function complete()
   local buf = util.current_buf()

   local pos = vim.api.nvim_win_get_cursor(0)
   local line = pos[1] - 1
   local col = pos[2]
   local crates = util.get_lines_crates(Range.new(line, line + 1))
   if not crates[1] then
      return
   end

   local crate = crates[1].crate
   local versions = crates[1].versions

   if not versions and api.is_fetching_vers(crate.name) then
      local _, cancelled = api.await_vers(crate.name)

      if cancelled or buf ~= util.current_buf() then
         return
      end

      pos = vim.api.nvim_win_get_cursor(0)
      line = pos[1] - 1
      col = pos[2]
      crates = util.get_lines_crates(Range.new(line, line + 1))
      if not crates[1] then
         return
      end

      crate = crates[1].crate
      versions = crates[1].versions
   end

   if not versions then
      return
   end

   if crate.vers and crate.vers.line == line and crate.vers.col:moved(0, 1):contains(col) then
      return complete_versions(crate, versions)
   elseif crate.feat and crate.feat.line == line and crate.feat.col:moved(0, 1):contains(col) then
      for _, f in ipairs(crate.feat.items) do
         if f.col:moved(0, 1):contains(col - crate.feat.col.s) then
            return complete_features(crate, f, versions)
         end
      end
   end
end

function M.complete(callback)
   async.launch(function()
      callback(complete())
   end)
end

return M
