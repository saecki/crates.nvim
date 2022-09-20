local M = {}




local api = require("crates.api")
local async = require("crates.async")
local diagnostic = require("crates.diagnostic")
local state = require("crates.state")
local toml = require("crates.toml")
local types = require("crates.types")
local Version = types.Version
local ui = require("crates.ui")
local util = require("crates.util")

M.reload_deps = async.wrap(function(crate_name, versions, version)
   local deps, cancelled = api.fetch_deps(crate_name, version.num)
   if cancelled then return end

   if deps then
      version.deps = deps
      for _, d in ipairs(deps) do

         if d.opt and not version.features:get_feat(d.name) then
            table.insert(version.features, {
               name = d.name,
               members = {},
            })
         end
      end
      version.features:sort()

      for b, cache in pairs(state.buf_cache) do

         for _, c in pairs(cache.crates) do
            if c.name == crate_name then
               local avoid_pre = state.cfg.avoid_prerelease and not c:vers_is_pre()
               local m, p, y = util.get_newest(versions, avoid_pre, c:vers_reqs())
               local match = m or p or y

               if c.vers and match == version and vim.api.nvim_buf_is_loaded(b) then
                  local diagnostics = diagnostic.process_crate_deps(c, version, deps)
                  ui.display_diagnostics(b, diagnostics)
               end
            end
         end
      end
   end
end)

local reload_crate = async.wrap(function(crate_name)
   local crate, cancelled = api.fetch_crate(crate_name)
   if cancelled then return end

   if crate then
      state.api_cache.crates[crate_name] = crate
   end
end)

local reload_vers = async.wrap(function(crate_name)
   local versions, cancelled = api.fetch_vers(crate_name)
   if cancelled then return end

   if versions and versions[1] then
      state.api_cache.versions[crate_name] = versions
   end

   for b, cache in pairs(state.buf_cache) do

      for k, c in pairs(cache.crates) do
         if c.name == crate_name and vim.api.nvim_buf_is_loaded(b) then
            local info, diagnostics = diagnostic.process_crate_versions(c, versions)
            cache.info[k] = info
            ui.display_crate_info(b, info, diagnostics)

            local version = info.vers_match or info.vers_upgrade
            if version then
               M.reload_deps(c.name, versions, version)
            end
         end
      end
   end
end)

function M.reload_crate(crate_name)
   reload_vers(crate_name)
   reload_crate(crate_name)
end

function M.update(buf, reload)
   buf = buf or util.current_buf()

   if reload then
      state.api_cache.crates = {}
      state.api_cache.versions = {}
      api.cancel_jobs()
   end

   local sections, crates = toml.parse_crates(buf)
   local crate_cache, diagnostics = diagnostic.process_crates(sections, crates)
   local cache = {
      crates = crate_cache,
      info = {},
      diagnostics = diagnostics,
   }
   state.buf_cache[buf] = cache

   ui.clear(buf)
   ui.display_diagnostics(buf, diagnostics)
   for k, c in pairs(crate_cache) do
      local versions = state.api_cache.versions[c.name]

      if not reload and versions then
         local info, v_diagnostics = diagnostic.process_crate_versions(c, versions)
         cache.info[k] = info
         vim.list_extend(cache.diagnostics, v_diagnostics)

         ui.display_crate_info(buf, info, v_diagnostics)

         local version = info.vers_match or info.vers_upgrade
         if version.deps then
            local d_diagnostics = diagnostic.process_crate_deps(c, version, version.deps)
            vim.list_extend(cache.diagnostics, d_diagnostics)

            ui.display_diagnostics(buf, d_diagnostics)
         else
            M.reload_deps(c.name, versions, version)
         end
      elseif c.vers and not (c.git or c.path) then
         if state.cfg.loading_indicator then
            ui.display_loading(buf, c)
         end

         M.reload_crate(c.name)
      end
   end
end

return M
