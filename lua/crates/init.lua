local M = {}





































































local actions = require("crates.actions")
local async = require("crates.async")
local config = require("crates.config")
local Config = config.Config
local core = require("crates.core")
local highlight = require("crates.highlight")
local popup = require("crates.popup")
local state = require("crates.state")
local ui = require("crates.ui")
local util = require("crates.util")





function M.setup(cfg)
   state.cfg = config.build(cfg)

   highlight.define()

   local group = vim.api.nvim_create_augroup("Crates", {})
   if state.cfg.autoload then
      if vim.fn.expand("%:t") == "Cargo.toml" then
         if state.cfg.src.cmp.enabled then
            require("crates.src.cmp").setup()
         end

         core.update(nil, false)
         state.cfg.on_attach(vim.api.nvim_get_current_buf())
      end

      vim.api.nvim_create_autocmd("BufRead", {
         group = group,
         pattern = "Cargo.toml",
         callback = function(info)
            if state.cfg.src.cmp.enabled then
               require("crates.src.cmp").setup()
            end

            core.update(nil, false)
            state.cfg.on_attach(info.buf)
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

function M.hide()
   state.visible = false
   for b, _ in pairs(state.buf_cache) do
      ui.clear(b)
   end
end

function M.show()
   state.visible = true


   local buf = util.current_buf()
   core.update(buf, false)

   for b, _ in pairs(state.buf_cache) do
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
