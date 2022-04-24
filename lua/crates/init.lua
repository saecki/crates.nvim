local M = {}



















































local actions = require("crates.actions")
local config = require("crates.config")
local Config = config.Config
local core = require("crates.core")
local popup = require("crates.popup")
local state = require("crates.state")
local ui = require("crates.ui")
local util = require("crates.util")

function M.setup(cfg)
   state.cfg = config.build(cfg)

   local group = vim.api.nvim_create_augroup("Crates", {})
   if state.cfg.autoload then
      vim.api.nvim_create_autocmd("BufRead", {
         group = group,
         pattern = "Cargo.toml",
         callback = function()
            M.update()
         end,
      })
   end
   if state.cfg.autoupdate then
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

   if state.cfg.src.coq.enabled then
      require("crates.src.coq").setup(state.cfg.src.coq.name)
   end
end

function M.hide()
   state.visible = false
   for b, _ in pairs(state.crate_cache) do
      ui.clear(b)
   end
end

function M.show()
   state.visible = true


   local buf = util.current_buf()
   core.update(buf, false)

   for b, _ in pairs(state.crate_cache) do
      if b ~= buf then
         core.update(b, false)
      end
   end
end

function M.toggle()
   if state.visible then
      M.hide()
   else
      M.show()
   end
end

function M.update(buf)
   core.update(buf, false)
end

function M.reload(buf)
   core.update(buf, true)
end

M.upgrade_crate = actions.upgrade_crate
M.upgrade_crates = actions.upgrade_crates
M.upgrade_all_crates = actions.upgrade_all_crates
M.update_crate = actions.update_crate
M.update_crates = actions.update_crates
M.update_all_crates = actions.update_all_crates

M.show_popup = popup.show
M.show_versions_popup = popup.show_versions
M.show_features_popup = popup.show_features
M.show_dependencies_popup = popup.show_dependencies
M.focus_popup = popup.focus
M.hide_popup = popup.hide

return M
