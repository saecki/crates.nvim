local M = {}



local core = require('crates.core')
local semver = require('crates.semver')
local util = require('crates.util')
local Crate = require('crates.toml').Crate
local Version = require('crates.api').Version

function M.display_versions(buf, crate, versions)
   if not core.visible or not crate.vers then
      vim.api.nvim_buf_clear_namespace(buf, M.namespace_id, crate.lines.s, crate.lines.e)
      return
   end

   local avoid_pre = core.cfg.avoid_prerelease and not crate:vers_has_suffix()
   local newest, newest_pre, newest_yanked = util.get_newest(versions, avoid_pre, nil)
   newest = newest or newest_pre or newest_yanked

   local virt_text
   if newest then
      if semver.matches_requirements(newest.parsed, crate:vers_reqs()) then

         virt_text = { { string.format(core.cfg.text.version, newest.num), core.cfg.highlight.version } }
      else

         local match, match_pre, match_yanked = util.get_newest(versions, avoid_pre, crate:vers_reqs())

         local upgrade_text = { string.format(core.cfg.text.upgrade, newest.num), core.cfg.highlight.upgrade }

         if match then

            virt_text = {
               { string.format(core.cfg.text.version, match.num), core.cfg.highlight.version },
               upgrade_text,
            }
         elseif match_pre then

            virt_text = {
               { string.format(core.cfg.text.prerelease, match_pre.num), core.cfg.highlight.prerelease },
               upgrade_text,
            }
         elseif match_yanked then

            virt_text = {
               { string.format(core.cfg.text.yanked, match_yanked.num), core.cfg.highlight.yanked },
               upgrade_text,
            }
         else

            virt_text = {
               { core.cfg.text.nomatch, core.cfg.highlight.nomatch },
               upgrade_text,
            }
         end
      end
   else
      virt_text = { { core.cfg.text.error, core.cfg.highlight.error } }
   end

   vim.api.nvim_buf_clear_namespace(buf, M.namespace_id, crate.lines.s, crate.lines.e)
   vim.api.nvim_buf_set_virtual_text(buf, M.namespace_id, crate.vers.line, virt_text, {})
end

function M.display_loading(buf, crate)
   local virt_text = { { core.cfg.text.loading, core.cfg.highlight.loading } }
   vim.api.nvim_buf_clear_namespace(buf, M.namespace_id, crate.lines.s, crate.lines.e)
   vim.api.nvim_buf_set_virtual_text(buf, M.namespace_id, crate.lines.s, virt_text, {})
end

function M.clear()
   if M.namespace_id then
      vim.api.nvim_buf_clear_namespace(0, M.namespace_id, 0, -1)
   end
   M.namespace_id = vim.api.nvim_create_namespace("crates.nvim")
end

return M
