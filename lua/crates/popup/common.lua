local M = {WinOpts = {}, HighlightText = {}, }





























local WinOpts = M.WinOpts
local HighlightText = M.HighlightText

local core = require("crates.core")

M.TOP_OFFSET = 2
M.NAMESPACE = vim.api.nvim_create_namespace("crates.nvim.popup")

function M.focus(line)
   if M.win and vim.api.nvim_win_is_valid(M.win) then
      vim.api.nvim_set_current_win(M.win)
      local l = math.min(line or 3, vim.api.nvim_buf_line_count(M.buf))
      vim.api.nvim_win_set_cursor(M.win, { l, 0 })
   end
end

function M.hide()
   if M.win and vim.api.nvim_win_is_valid(M.win) then
      vim.api.nvim_win_close(M.win, false)
   end
   M.win = nil

   if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
      vim.api.nvim_buf_delete(M.buf, {})
   end
   M.buf = nil
   M.type = nil

   M.transaction = nil
end

function M.win_height(entries)
   return math.min(
   #entries + M.TOP_OFFSET,
   core.cfg.popup.max_height)

end

function M.win_width(title, content_width)
   return math.max(
   vim.fn.strdisplaywidth(title) + vim.fn.strdisplaywidth(core.cfg.popup.text.loading),
   content_width,
   core.cfg.popup.min_width)

end

local function set_buf_content(buf, title, text)
   vim.api.nvim_buf_set_option(buf, "modifiable", true)


   vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
   vim.api.nvim_buf_clear_namespace(buf, M.NAMESPACE, 0, -1)


   vim.api.nvim_buf_set_lines(buf, 0, 2, false, { title, "" })
   vim.api.nvim_buf_add_highlight(buf, M.NAMESPACE, core.cfg.popup.highlight.title, 0, 0, -1)

   for i, v in ipairs(text) do
      vim.api.nvim_buf_set_lines(buf, M.TOP_OFFSET + i - 1, M.TOP_OFFSET + i, false, { v.text .. (v.suffix or "") })
      vim.api.nvim_buf_add_highlight(buf, M.NAMESPACE, v.hl, M.TOP_OFFSET + i - 1, 0, v.text:len())
      if v.suffix_hl then
         vim.api.nvim_buf_add_highlight(buf, M.NAMESPACE, v.suffix_hl, M.TOP_OFFSET + i - 1, v.text:len(), -1)
      end
   end

   vim.api.nvim_buf_set_name(buf, "crates")
   vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

function M.update_win(width, height, title, text, opts)

   vim.api.nvim_win_set_width(M.win, width)
   vim.api.nvim_win_set_height(M.win, height)


   set_buf_content(M.buf, title, text)


   local l = math.min(opts.line or 3, vim.api.nvim_buf_line_count(M.buf))
   vim.api.nvim_win_set_cursor(M.win, { l, 0 })
end

function M.open_win(width, height, title, text, opts, configure)
   M.buf = vim.api.nvim_create_buf(false, true)


   set_buf_content(M.buf, title, text)


   M.win = vim.api.nvim_open_win(M.buf, false, {
      relative = "cursor",
      col = 0,
      row = 1,
      width = width,
      height = height,
      style = core.cfg.popup.style,
      border = core.cfg.popup.border,
   })


   for _, k in ipairs(core.cfg.popup.keys.hide) do
      vim.api.nvim_buf_set_keymap(M.buf, "n", k, "", {
         callback = function()
            M.hide()
         end,
         noremap = true,
         silent = true,
         desc = "Hide popup",
      })
   end

   if configure then
      configure(M.win, M.buf)
   end


   if opts and opts.focus or core.cfg.popup.autofocus then
      M.focus(opts and opts.line)
   end
end

return M
