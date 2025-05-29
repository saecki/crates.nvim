local state = require("crates.state")

---@class Popup
---@field TOP_OFFSET integer
---@field POPUP_NS integer
---@field LOADING_NS integer
--
---@field win integer?
---@field buf integer?
---@field type PopupType?
---@field transaction number?
local M = {
    TOP_OFFSET = 2,
    POPUP_NS = vim.api.nvim_create_namespace("crates.nvim.popup"),
    LOADING_NS = vim.api.nvim_create_namespace("crates.nvim.popup.loading"),
}

---@enum PopupType
M.Type = {
    CRATE = 1,
    VERSIONS = 2,
    FEATURES = 3,
    FEATURE_DETAILS = 4,
    DEPENDENCIES = 5,
}

---@class WinOpts
---@field focus boolean?
---@field line integer? -- 1 indexed
---@field update boolean?

---@class HighlightText
---@field text string
---@field hl string

---0-indexed
---@param line integer?
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
    for _, line in ipairs(text) do
        local padding = string.rep(" ", state.cfg.popup.padding)
        local line_text = padding
        for _, t in ipairs(line) do
            line_text = line_text .. t.text
        end
        line_text = line_text .. padding
        table.insert(lines, line_text)
    end
    vim.api.nvim_buf_set_lines(M.buf, M.TOP_OFFSET, M.TOP_OFFSET + #lines, false, lines)

    for i, line in ipairs(text) do
        local pos = state.cfg.popup.padding
        for _, t in ipairs(line) do
            vim.api.nvim_buf_set_extmark(M.buf, M.POPUP_NS, M.TOP_OFFSET + i - 1, pos, {
                end_col = pos + t.text:len(),
                hl_group = t.hl,
            })
            pos = pos + t.text:len()
        end
    end
end

---@param text HighlightText[][]
function M.update_buf_body(text)
    vim.api.nvim_set_option_value("modifiable", true, { buf = M.buf })
    set_buf_body(text)
    vim.api.nvim_set_option_value("modifiable", false, { buf = M.buf })
end

---@param buf integer
---@param title string
---@param text HighlightText[][]
local function set_buf_content(buf, title, text)
    local opts = { buf = buf }
    vim.api.nvim_set_option_value("modifiable", true, opts)

    -- clear buffer
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    vim.api.nvim_buf_clear_namespace(buf, M.POPUP_NS, 0, -1)

    -- update buffer
    local padding = string.rep(" ", state.cfg.popup.padding)
    local title_text = padding .. title .. padding
    vim.api.nvim_buf_set_lines(buf, 0, 2, false, { title_text, "" })
    vim.api.nvim_buf_set_extmark(buf, M.POPUP_NS, 0, 0, {
        end_col = title_text:len(),
        hl_group = state.cfg.popup.highlight.title,
    })

    set_buf_body(text)

    vim.api.nvim_set_option_value("modifiable", false, opts)
    vim.api.nvim_set_option_value("buftype", "nofile", opts)
    vim.api.nvim_set_option_value("swapfile", false, opts)
    vim.api.nvim_set_option_value("filetype", "crates.nvim", opts)
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

--- Get the border of the popup menu.
---
--- Returns the first valid value out of the following choices (in that order):
--- 1. Config value `popup.border`, if configured
--- 2. Global `winborder`, if neovim version >= 0.11.0
--- 3. `"none"`
local function popup_border()
    if state.cfg.popup.border ~= nil then
        return state.cfg.popup.border
    elseif vim.version.ge(vim.version(), {0, 11, 0}) then
        return vim.opt_global.winborder:get()
    else
        return "none"
    end
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
        border = popup_border(),
    })

    -- add key mappings
    for _, k in ipairs(state.cfg.popup.keys.hide) do
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

---@param transaction number?
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
