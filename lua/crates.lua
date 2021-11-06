local M = {}







local api = require('crates.api')
local Version = api.Version
local Config = require('crates.config')
local core = require('crates.core')
local popup = require('crates.popup')
local toml = require('crates.toml')
local Crate = toml.Crate
local util = require('crates.util')
local ui = require('crates.ui')
local Range = require('crates.types').Range

function M.reload_crate(crate)
   local function on_fetched(versions)
      if versions and versions[1] then
         core.vers_cache[crate.name] = versions
      end

      for buf, crates in pairs(core.crate_cache) do
         local c = crates[crate.name]


         if c and vim.api.nvim_buf_is_loaded(buf) then
            ui.display_versions(buf, c, versions)
         end
      end
   end

   if core.cfg.loading_indicator then
      ui.display_loading(0, crate)
   end

   api.fetch_crate_versions(crate.name, on_fetched)
end

function M.hide()
   core.visible = false
   ui.clear()
end

function M.reload()
   core.visible = true
   core.vers_cache = {}
   ui.clear()

   local cur_buf = util.current_buf()
   local crates = toml.parse_crates(0)

   core.crate_cache[cur_buf] = {}

   for _, c in ipairs(crates) do
      core.crate_cache[cur_buf][c.name] = c
      M.reload_crate(c)
   end
end

function M.update()
   core.visible = true
   ui.clear()

   local cur_buf = util.current_buf()
   local crates = toml.parse_crates(0)

   core.crate_cache[cur_buf] = {}

   for _, c in ipairs(crates) do
      local versions = core.vers_cache[c.name]

      core.crate_cache[cur_buf][c.name] = c

      if versions then
         ui.display_versions(0, c, versions)
      else
         M.reload_crate(c)
      end
   end
end

function M.toggle()
   if core.visible then
      M.hide()
   else
      M.update()
   end
end



function M.upgrade_crate(smart)
   local linenr = vim.api.nvim_win_get_cursor(0)[1]
   util.upgrade_crates(Range.pos(linenr - 1), smart)
end


function M.upgrade_crates(smart)
   local lines = Range.new(
   vim.api.nvim_buf_get_mark(0, "<")[1] - 1,
   vim.api.nvim_buf_get_mark(0, ">")[1])

   util.upgrade_crates(lines, smart)
end


function M.upgrade_all_crates(smart)
   local lines = Range.new(0, vim.api.nvim_buf_line_count(0))
   util.upgrade_crates(lines, smart)
end


function M.update_crate(smart)
   local linenr = vim.api.nvim_win_get_cursor(0)[1]
   util.update_crates(Range.pos(linenr - 1), smart)
end


function M.update_crates(smart)
   local lines = Range.new(
   vim.api.nvim_buf_get_mark(0, "<")[1] - 1,
   vim.api.nvim_buf_get_mark(0, ">")[1])

   util.update_crates(lines, smart)
end


function M.update_all_crates(smart)
   local lines = Range.new(0, vim.api.nvim_buf_line_count(0))
   util.update_crates(lines, smart)
end


function M.setup(cfg)
   local default = Config.default()
   if cfg then
      core.cfg = vim.tbl_deep_extend("keep", cfg, default)
   else
      core.cfg = vim.tbl_deep_extend("keep", core.cfg, default)
   end

   vim.cmd("augroup Crates")
   vim.cmd("autocmd!")
   if core.cfg.autoload then
      vim.cmd("autocmd BufRead Cargo.toml lua require('crates').update()")
   end
   if core.cfg.autoupdate then
      vim.cmd("autocmd TextChanged,TextChangedI,TextChangedP Cargo.toml lua require('crates').update()")
   end
   vim.cmd("augroup END")

   vim.cmd([[
        augroup CratesPopup
        autocmd!
        autocmd CursorMoved,CursorMovedI Cargo.toml lua require('crates.popup').hide()
        augroup END
    ]])
end

M.show_popup = popup.show
M.show_versions_popup = popup.show_versions
M.show_features_popup = popup.show_features
M.focus_popup = popup.focus
M.hide_popup = popup.hide

return M
