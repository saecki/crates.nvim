local M = {}

local cmp = require('cmp')
local lsp = cmp.lsp
local core = require('crates.core')
local util = require('crates.util')
local Range = require('crates.types').Range
local Version = require('crates.api').Version
local Crate = require('crates.toml').Crate


function M.new()
   return setmetatable({}, { __index = M })
end


function M.get_debug_name()
   return 'crates'
end


function M:is_available()
   return vim.fn.expand("%:t") == "Cargo.toml"
end





function M:get_keyword_pattern(_)
   return [[\([^"'\%^<>=~,\s]\)*]]
end


function M:get_trigger_characters(_)
   return { '"', "'", ".", "<", ">", "=", "^", "~", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
end

local function complete_versions(crate, versions)
   local results = {}

   for i, v in ipairs(versions) do
      local r = {
         label = v.num,
         kind = cmp.lsp.CompletionItemKind.Value,
         sortText = string.format("%04d", i),
      }
      if core.cfg.cmp.closing_quote then
         if crate.vers and not crate.vers.quote.e then
            r.insertText = v.num .. crate.vers.quote.s
         end
      end
      if v.yanked then
         r.deprecated = true
         r.documentation = core.cfg.cmp.text.yanked
      elseif v.parsed.pre then
         r.documentation = core.cfg.cmp.text.prerelease
      end

      table.insert(results, r)
   end

   return results
end

local function complete_features(crate, versions)
   local results = {}

   local avoid_pre = core.cfg.avoid_prerelease and not crate:vers_is_pre()
   local newest = util.get_newest(versions, avoid_pre, crate:vers_reqs())

   for _, f in ipairs(newest.features) do
      local crate_feat = crate:get_feat(f.name)
      if not crate_feat then
         local r = {
            label = f.name,
            kind = cmp.lsp.CompletionItemKind.Value,
            sortText = f.name,
            documentation = table.concat(f.members, "\n"),
         }

         table.insert(results, r)
      end
   end

   return results
end



function M:complete(_, callback)
   local pos = vim.api.nvim_win_get_cursor(0)
   local line = pos[1] - 1
   local col = pos[2]

   local crates = util.get_lines_crates(Range.new(line, line + 1))
   if not crates or not crates[1] or not crates[1].versions then
      callback(nil)
      return
   end

   local crate = crates[1].crate
   local versions = crates[1].versions

   if crate.vers and crate.vers.line == line and crate.vers.col:moved(0, 1):contains(col) then
      callback(complete_versions(crate, versions))
   elseif crate.feat and crate.feat.line == line and crate.feat.col:moved(0, 1):contains(col) then
      for _, f in ipairs(crate.feat.items) do
         if f.col:moved(0, 1):contains(col - crate.feat.col.s) then
            callback(complete_features(crate, versions))
            return
         end
      end

      callback(nil)
   else
      callback(nil)
   end
end

return M
