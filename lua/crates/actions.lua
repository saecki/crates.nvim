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
   local buf = util.current_buf()
   local linenr = vim.api.nvim_win_get_cursor(0)[1]
   local crates = util.get_line_crates(buf, Range.pos(linenr - 1))
   local info = state.info_cache[buf]
   if next(crates) and info then
      util.upgrade_crates(buf, crates, info, alt)
   end
end

function M.upgrade_crates(alt)
   local buf = util.current_buf()
   local lines = Range.new(
   vim.api.nvim_buf_get_mark(0, "<")[1] - 1,
   vim.api.nvim_buf_get_mark(0, ">")[1])

   local crates = util.get_line_crates(buf, lines)
   local info = state.info_cache[buf]
   if next(crates) and info then
      util.upgrade_crates(buf, crates, info, alt)
   end
end

function M.upgrade_all_crates(alt)
   local buf = util.current_buf()
   local crates = state.crate_cache[buf]
   local info = state.info_cache[buf]
   if crates and info then
      util.upgrade_crates(buf, crates, info, alt)
   end
end

function M.update_crate(alt)
   local buf = util.current_buf()
   local linenr = vim.api.nvim_win_get_cursor(0)[1]
   local crates = util.get_line_crates(buf, Range.pos(linenr - 1))
   local info = state.info_cache[buf]
   if next(crates) and info then
      util.update_crates(buf, crates, info, alt)
   end
end

function M.update_crates(alt)
   local buf = util.current_buf()
   local lines = Range.new(
   vim.api.nvim_buf_get_mark(0, "<")[1] - 1,
   vim.api.nvim_buf_get_mark(0, ">")[1])

   local crates = util.get_line_crates(buf, lines)
   local info = state.info_cache[buf]
   if next(crates) and info then
      util.update_crates(buf, crates, info, alt)
   end
end

function M.update_all_crates(alt)
   local buf = util.current_buf()
   local crates = state.crate_cache[buf]
   local info = state.info_cache[buf]
   if crates and info then
      util.update_crates(buf, crates, info, alt)
   end
end

return M
