local M = {}



















































local config = require("crates.config")
local Config = config.Config
local core = require("crates.core")
local popup = require("crates.popup")
local state = require("crates.state")
local types = require("crates.types")
local Range = types.Range
local ui = require("crates.ui")
local util = require("crates.util")

function M.setup(cfg)
   core.cfg = config.build(cfg)

   local group = vim.api.nvim_create_augroup("Crates", {})
   if core.cfg.autoload then
      vim.api.nvim_create_autocmd("BufRead", {
         group = group,
         pattern = "Cargo.toml",
         callback = function()
            M.update()
         end,
      })
   end
   if core.cfg.autoupdate then
      vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
         group = group,
         pattern = "Cargo.toml",
         callback = function()
            M.update()
         end,
      })
   end
   vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
      group = group,
      pattern = "Cargo.toml",
      callback = function()
         popup.hide()
      end,
   })

   if core.cfg.src.coq.enabled then
      require("crates.src.coq").setup(core.cfg.src.coq.name)
   end
end

function M.hide()
   core.visible = false
   for b, _ in pairs(core.crate_cache) do
      ui.clear(b)
   end
end

function M.show()
   core.visible = true


   local buf = util.current_buf()
   state.update(buf, false)

   for b, _ in pairs(core.crate_cache) do
      if b ~= buf then
         state.update(b, false)
      end
   end
end

function M.toggle()
   if core.visible then
      M.hide()
   else
      M.show()
   end
end

function M.update(buf)
   state.update(buf, false)
end

function M.reload(buf)
   state.update(buf, true)
end


function M.upgrade_crate(alt)
   local linenr = vim.api.nvim_win_get_cursor(0)[1]
   local crates = util.get_lines_crates(Range.pos(linenr - 1))
   util.upgrade_crates(crates, alt)
end

function M.upgrade_crates(alt)
   local lines = Range.new(
   vim.api.nvim_buf_get_mark(0, "<")[1] - 1,
   vim.api.nvim_buf_get_mark(0, ">")[1])

   local crates = util.get_lines_crates(lines)
   util.upgrade_crates(crates, alt)
end

function M.upgrade_all_crates(alt)
   local cur_buf = util.current_buf()
   local crates = core.crate_cache[cur_buf]
   if not crates then return end

   local crate_versions = {}
   for _, c in pairs(crates) do
      table.insert(crate_versions, {
         crate = c,
         versions = core.vers_cache[c.name],
      })
   end

   util.upgrade_crates(crate_versions, alt)
end

function M.update_crate(alt)
   local linenr = vim.api.nvim_win_get_cursor(0)[1]
   local crates = util.get_lines_crates(Range.pos(linenr - 1))
   util.update_crates(crates, alt)
end

function M.update_crates(alt)
   local lines = Range.new(
   vim.api.nvim_buf_get_mark(0, "<")[1] - 1,
   vim.api.nvim_buf_get_mark(0, ">")[1])

   local crates = util.get_lines_crates(lines)
   util.update_crates(crates, alt)
end

function M.update_all_crates(alt)
   local cur_buf = util.current_buf()
   local crates = core.crate_cache[cur_buf]
   if not crates then return end

   local crate_versions = {}
   for _, c in pairs(crates) do
      table.insert(crate_versions, {
         crate = c,
         versions = core.vers_cache[c.name],
      })
   end

   util.update_crates(crate_versions, alt)
end

M.show_popup = popup.show
M.show_versions_popup = popup.show_versions
M.show_features_popup = popup.show_features
M.show_dependencies_popup = popup.show_dependencies
M.focus_popup = popup.focus
M.hide_popup = popup.hide

return M
