local M = {}

local util = require("crates.util")
local state = require("crates.state")
local toml = require("crates.toml")
local types = require("crates.types")
local Diagnostic = types.Diagnostic
local Range = types.Range

function M.upgrade_crate(alt)
   local buf = util.current_buf()
   local line = util.cursor_pos()
   local crates = util.get_line_crates(buf, Range.pos(line))
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
   local line = util.cursor_pos()
   local crates = util.get_line_crates(buf, Range.pos(line))
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

function M.open_docs_rs()
   local buf = util.current_buf()
   local line = util.cursor_pos()
   local crates = util.get_line_crates(buf, Range.pos(line))
   local _, crate = next(crates)
   if crate then
      util.open_url("https://docs.rs/" .. crate.name)
   end
end

function M.open_crates_io()
   local buf = util.current_buf()
   local line = util.cursor_pos()
   local crates = util.get_line_crates(buf, Range.pos(line))
   local _, crate = next(crates)
   if crate then
      util.open_url("https://crates.io/crates/" .. crate.name)
   end
end

local function remove_diagnostic_range_action(buf, d)
   return function()
      vim.api.nvim_buf_set_text(buf, d.lnum, d.col, d.end_lnum, d.end_col, {})
   end
end

local function remove_lines_action(buf, lines)
   return function()
      vim.api.nvim_buf_set_lines(buf, lines.s, lines.e, false, {})
   end
end

local function remove_feature_action(buf, crate, feat)
   return function()
      util.disable_feature(buf, crate, feat)
   end
end

function M.get_actions()
   local actions = {}

   local buf = util.current_buf()
   local line, col = util.cursor_pos()
   local crates = util.get_line_crates(buf, Range.pos(line))
   local key, crate = next(crates)
   if crate then
      local info = util.get_crate_info(buf, key)
      if info then
         if info.vers_update then
            actions["update_crate"] = M.update_crate
         end
         if info.vers_upgrade then
            actions["upgrade_crate"] = M.upgrade_crate
         end
      end
   end
   local diagnostics = state.diagnostic_cache[buf] or {}
   for _, d in ipairs(diagnostics) do
      if not d:contains(line, col) then
         goto continue
      end

      if d.kind == "section_dup" then
         actions["remove_duplicate_section"] = remove_diagnostic_range_action(buf, d)
      elseif d.kind == "section_dup_orig" then
         actions["remove_original_section"] = remove_lines_action(buf, d.data["lines"])
      elseif d.kind == "section_invalid" then
         actions["remove_invalid_dependency_section"] = remove_diagnostic_range_action(buf, d)

      elseif d.kind == "crate_dup" then
         actions["remove_duplicate_crate"] = remove_diagnostic_range_action(buf, d)
      elseif d.kind == "crate_dup_orig" then
         actions["remove_original_crate"] = remove_diagnostic_range_action(buf, d)

      elseif crate and d.kind == "feat_dup" then
         actions["remove_duplicate_feature"] = remove_feature_action(buf, crate, d.data["feat"])
      elseif crate and d.kind == "feat_dup_orig" then
         actions["remove_original_feature"] = remove_feature_action(buf, crate, d.data["feat"])
      elseif crate and d.kind == "feat_invalid" then
         actions["remove_invalid_feature"] = remove_feature_action(buf, crate, d.data["feat"])
      end

      ::continue::
   end

   if crate then
      actions["open_docs.rs"] = M.open_docs_rs
      actions["open_crates.io"] = M.open_crates_io
   end

   actions["update_all_crates"] = M.update_all_crates
   actions["upgrade_all_crates"] = M.upgrade_all_crates

   return actions
end

return M
