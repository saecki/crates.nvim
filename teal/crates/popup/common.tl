local record M
    TOP_OFFSET: integer
    POPUP_NS: integer
    LOADING_NS: integer

    win: integer|nil
    buf: integer|nil
    type: Type|nil
    transaction: number|nil

    enum Type
        "crate"
        "versions"
        "features"
        "feature_details"
        "dependencies"
    end

    record WinOpts
        focus: boolean
        line: integer -- 1 indexed
        update: boolean
    end

    record HighlightText
        text: string
        hl: string
    end
end

local HighlightText = M.HighlightText
local WinOpts = M.WinOpts
local state = require("crates.state")

M.TOP_OFFSET = 2
M.POPUP_NS = vim.api.nvim_create_namespace("crates.nvim.popup") as integer
M.LOADING_NS = vim.api.nvim_create_namespace("crates.nvim.popup.loading") as integer

-- 0-indexed
function M.focus(line: integer|nil)
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

function M.item_index(line: integer): integer
    return line - M.TOP_OFFSET + 1
end

function M.win_height<T>(entries: {T}): integer
    return math.min(
        #entries + M.TOP_OFFSET,
        state.cfg.popup.max_height
    )
end

function M.win_width(title: string, content_width: integer): integer
    return math.max(
        vim.fn.strdisplaywidth(title) as integer + vim.fn.strdisplaywidth(state.cfg.popup.text.loading) as integer,
        content_width,
        state.cfg.popup.min_width
    ) + 2 * state.cfg.popup.padding
end

local function set_buf_body(text: {{HighlightText}})
    for i,line in ipairs(text) do
        local padding = string.rep(" ", state.cfg.popup.padding)
        local line_text = padding
        for _,t in ipairs(line) do
            line_text = line_text .. t.text
        end
        line_text = line_text .. padding

        vim.api.nvim_buf_set_lines(M.buf, M.TOP_OFFSET + i - 1, M.TOP_OFFSET + i, false, { line_text })
        local pos = state.cfg.popup.padding
        for _,t in ipairs(line) do
            vim.api.nvim_buf_add_highlight(M.buf, M.POPUP_NS, t.hl, M.TOP_OFFSET + i - 1, pos, pos + t.text:len())
            pos = pos + t.text:len()
        end
    end
end

function M.update_buf_body(text: {{HighlightText}})
    vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
    set_buf_body(text)
    vim.api.nvim_buf_set_option(M.buf, "modifiable", false)
end

local function set_buf_content(buf: integer, title: string, text: {{HighlightText}})
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

function M.update_win(width: integer, height: integer, title: string, text: {{HighlightText}}, opts: WinOpts)
    -- resize window
    vim.api.nvim_win_set_width(M.win, width)
    vim.api.nvim_win_set_height(M.win, height)

    -- update text and highlights
    set_buf_content(M.buf, title, text)

    -- set line
    local l = math.min((opts.line or 2) + 1, vim.api.nvim_buf_line_count(M.buf))
    vim.api.nvim_win_set_cursor(M.win, { l, 0 })
end

function M.open_win(width: integer, height: integer, title: string, text: {{HighlightText}}, opts: WinOpts, configure: function(integer, integer))
    M.buf = vim.api.nvim_create_buf(false, true) as integer

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
    }) as integer

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
    if opts and opts.focus or state.cfg.popup.autofocus then
        M.focus(opts and opts.line)
    end
end


function M.hide_loading_indicator(transaction: number)
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
