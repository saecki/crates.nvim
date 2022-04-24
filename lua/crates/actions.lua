local M = {}

local util = require("crates.util")
local state = require("crates.state")
local types = require("crates.types")
local Range = types.Range

function M.get_actions()
   local actions = {}
   local function add_action(action)
      actions[action] = (M)[action]
   end

   add_action("update_all_crates")
   add_action("upgrade_all_crates")

   return actions
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
   local crates = state.crate_cache[cur_buf]
   if not crates then return end

   local crate_versions = {}
   for _, c in pairs(crates) do
      table.insert(crate_versions, {
         crate = c,
         versions = state.vers_cache[c.name],
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
   local crates = state.crate_cache[cur_buf]
   if not crates then return end

   local crate_versions = {}
   for _, c in pairs(crates) do
      table.insert(crate_versions, {
         crate = c,
         versions = state.vers_cache[c.name],
      })
   end

   util.update_crates(crate_versions, alt)
end

return M
