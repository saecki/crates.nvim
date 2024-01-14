local M = {}





































































local actions = require("crates.actions")
local async = require("crates.async")
local command = require("crates.command")
local config = require("crates.config")
local Config = config.Config
local core = require("crates.core")
local highlight = require("crates.highlight")
local popup = require("crates.popup")
local state = require("crates.state")






function M.attach()
   if state.cfg.src.cmp.enabled then
      require("crates.src.cmp").setup()
   end

   if state.cfg.lsp.enabled then
      require("crates.lsp").start_server()
   end

   core.update()
   state.cfg.on_attach(vim.api.nvim_get_current_buf())
end

function M.setup(cfg)
   state.cfg = config.build(cfg)

   command.register()
   highlight.define()

   local group = vim.api.nvim_create_augroup("Crates", {})
   if state.cfg.autoload then
      if vim.fn.expand("%:t") == "Cargo.toml" then
         M.attach()
      end

      vim.api.nvim_create_autocmd("BufRead", {
         group = group,
         pattern = "Cargo.toml",
         callback = function(_)
            M.attach()
         end,
      })
   end


   core.inner_throttled_update = async.throttle(M.update, state.cfg.autoupdate_throttle)

   if state.cfg.autoupdate then
      vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
         group = group,
         pattern = "Cargo.toml",
         callback = function()
            core.throttled_update(nil, false)
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

   if state.cfg.null_ls.enabled then
      require("crates.null-ls").setup(state.cfg.null_ls.name)
   end
end

M.hide = core.hide
M.show = core.show
M.toggle = core.toggle
M.update = core.update
M.reload = core.reload

M.upgrade_crate = actions.upgrade_crate
M.upgrade_crates = actions.upgrade_crates
M.upgrade_all_crates = actions.upgrade_all_crates
M.update_crate = actions.update_crate
M.update_crates = actions.update_crates
M.update_all_crates = actions.update_all_crates

M.expand_plain_crate_to_inline_table = actions.expand_plain_crate_to_inline_table
M.extract_crate_into_table = actions.extract_crate_into_table

M.open_homepage = actions.open_homepage
M.open_repository = actions.open_repository
M.open_documentation = actions.open_documentation
M.open_crates_io = actions.open_crates_io

M.popup_available = popup.available
M.show_popup = popup.show
M.show_crate_popup = popup.show_crate
M.show_versions_popup = popup.show_versions
M.show_features_popup = popup.show_features
M.show_dependencies_popup = popup.show_dependencies
M.focus_popup = popup.focus
M.hide_popup = popup.hide

return M
