local state = require("crates.state")

---@class Popup
---@field TOP_OFFSET integer
---@field POPUP_NS integer
---@field LOADING_NS integer
--
---@field win integer|nil
---@field buf integer|nil
---@field type PopupType|nil
---@field transaction number|nil
local M = {
    TOP_OFFSET = 2,
    POPUP_NS = vim.api.nvim_create_namespace("crates.nvim.popup"),
    LOADING_NS = vim.api.nvim_create_namespace("crates.nvim.popup.loading"),
}

---@enum PopupType
M.Type = {
    crate = 1,
    versions = 2,
    features = 3,
    feature_details = 4,
    dependencies = 5,
}

---@class WinOpts
---@field focus boolean|nil
---@field line integer|nil -- 1 indexed
---@field update boolean|nil

---@class HighlightText
---@field text string
---@field hl string

---0-indexed
---@param line integer|nil
function M.focus(line)
    if M.win and vim.api.nvim_win_is_valid(M.win) then
        vim.api.nvim_set_current_win(M.win)
        local l = math.min((line or 2) + 1, vim.api.nvim_buf_line_count(M.buf))
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
    -- omit loading transaction if any
    M.transaction = nil
end

---comment
---@param line integer
---@return integer
function M.item_index(line)
    return line - M.TOP_OFFSET + 1
end

---@param entries any[]
---@return integer
function M.win_height(entries)
    return math.min(
        #entries + M.TOP_OFFSET,
        state.cfg.popup.max_height
    )
end

---@param title string
---@param content_width integer
---@return integer
function M.win_width(title, content_width)
    return math.max(
        vim.fn.strdisplaywidth(title) + vim.fn.strdisplaywidth(state.cfg.popup.text.loading),
        content_width,
        state.cfg.popup.min_width
    ) + 2 * state.cfg.popup.padding
end

---@param text HighlightText[][]
local function set_buf_body(text)
    local lines = {}
    for _,line in ipairs(text) do
        local padding = string.rep(" ", state.cfg.popup.padding)
        local line_text = padding
        for _,t in ipairs(line) do
            line_text = line_text .. t.text
        end
        line_text = line_text .. padding
        table.insert(lines, line_text)
    end
    vim.api.nvim_buf_set_lines(M.buf, M.TOP_OFFSET, M.TOP_OFFSET + #lines, false, lines)

    for i,line in ipairs(text) do
        local pos = state.cfg.popup.padding
        for _,t in ipairs(line) do
            vim.api.nvim_buf_add_highlight(M.buf, M.POPUP_NS, t.hl, M.TOP_OFFSET + i - 1, pos, pos + t.text:len())
            pos = pos + t.text:len()
        end
    end
end

---@param text HighlightText[][]
function M.update_buf_body(text)
    vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
    set_buf_body(text)
    vim.api.nvim_buf_set_option(M.buf, "modifiable", false)
end

---@param buf integer
---@param title string
---@param text HighlightText[][]
local function set_buf_content(buf, title, text)
    vim.api.nvim_buf_set_option(buf, "modifiable", true)

    -- clear buffer
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    vim.api.nvim_buf_clear_namespace(buf, M.POPUP_NS, 0, -1)

    -- update buffer
    local padding = string.rep(" ", state.cfg.popup.padding)
    local title_text = padding .. title .. padding
    vim.api.nvim_buf_set_lines(buf, 0, 2, false, { title_text, "" })
    vim.api.nvim_buf_add_highlight(buf, M.POPUP_NS, state.cfg.popup.highlight.title, 0, 0, -1)

    set_buf_body(text)

    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf, "swapfile", false)
    vim.api.nvim_buf_set_option(buf, "filetype", "crates.nvim")
    vim.api.nvim_buf_set_name(buf, "crates:popup")
end

---@param width integer
---@param height integer
---@param title string
---@param text HighlightText[][]
---@param opts WinOpts
function M.update_win(width, height, title, text, opts)
    -- resize window
    vim.api.nvim_win_set_width(M.win, width)
    vim.api.nvim_win_set_height(M.win, height)

    -- update text and highlights
    set_buf_content(M.buf, title, text)

    -- set line
    local l = math.min((opts.line or 2) + 1, vim.api.nvim_buf_line_count(M.buf))
    vim.api.nvim_win_set_cursor(M.win, { l, 0 })
end

---@param width integer
---@param height integer
---@param title string
---@param text HighlightText[][]
---@param opts WinOpts
---@param configure fun(win: integer, buf: integer)
function M.open_win(width, height, title, text, opts, configure)
    M.buf = vim.api.nvim_create_buf(false, true)

    -- add text and highlights
    set_buf_content(M.buf, title, text)

    -- create window
    M.win = vim.api.nvim_open_win(M.buf, false, {
        relative = "cursor",
        col = 0,
        row = 1,
        width = width,
        height = height,
        style = state.cfg.popup.style,
        border = state.cfg.popup.border,
    })

    -- add key mappings
    for _,k in ipairs(state.cfg.popup.keys.hide) do
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

    -- autofocus
    if opts.focus or state.cfg.popup.autofocus then
        M.focus(opts.line)
    end
end

---@param transaction number|nil
function M.hide_loading_indicator(transaction)
    if transaction and transaction ~= M.transaction then
        return
    end
    if M.buf then
        vim.api.nvim_buf_clear_namespace(M.buf, M.LOADING_NS, 0, 1)
    end
end

function M.show_loading_indicator()
    if M.buf then
        vim.api.nvim_buf_clear_namespace(M.buf, M.LOADING_NS, 0, 1)
        vim.api.nvim_buf_set_extmark(M.buf, M.LOADING_NS, 0, -1, {
            virt_text = { { state.cfg.popup.text.loading, state.cfg.popup.highlight.loading } },
            virt_text_pos = "right_align",
            hl_mode = "combine",
        })
    end
end

function M.omit_loading_transaction()
    M.transaction = nil
    M.hide_loading_indicator()
end

return M
