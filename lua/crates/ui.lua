local state = require("crates.state")
local types = require("crates.types")
local MatchKind = types.MatchKind

---@class Ui
---@field state table<integer,BufUiState>
local M = {
    state = {},
}

---@class BufUiState
---@field custom_diagnostics vim.Diagnostic[]
---@field diagnostics vim.Diagnostic[]
---@field search_transaction SearchTransaction?
---@field line_state table<integer,LineState>
---@field loading_timer uv.uv_timer_t?
---@field loading_frame integer
---@field loading_lines table<integer,boolean>

---@class SearchTransaction
---@field id number
---@field line integer

---@enum LineState
local LineState = {
    SEARCHING = 1,
    LOADING = 2,
    UPDATE = 3,
}

local LOADING_FRAMES = {
    "⠋",
    "⠙",
    "⠹",
    "⠸",
    "⠼",
    "⠴",
    "⠦",
    "⠧",
    "⠇",
    "⠏",
}

---@param buf integer
---@return BufUiState
function M.get_or_init(buf)
    local buf_state  = M.state[buf] or {
        custom_diagnostics = {},
        diagnostics = {},
        line_state = {},
        loading_frame = 1,
        loading_lines = {},
    }
    M.state[buf] = buf_state
    return buf_state
end

---@type integer
local CUSTOM_NS = vim.api.nvim_create_namespace("crates.nvim")
---@type integer
local LOADING_NS = vim.api.nvim_create_namespace("crates.nvim.loading")
---@type integer
local DIAGNOSTIC_NS = vim.api.nvim_create_namespace("crates.nvim.diagnostic")

---@param text string
---@param frame string
---@return string
local function loading_text(text, frame)
    local replaced = text:gsub("^(%s*)%S+", "%1" .. frame, 1)
    return replaced
end

---@param buf_state BufUiState
local function stop_loading_timer(buf_state)
    if buf_state.loading_timer then
        buf_state.loading_timer:stop()
        buf_state.loading_timer:close()
        buf_state.loading_timer = nil
    end
end

---@param buf integer
---@param buf_state BufUiState
---@param line integer
local function hide_loading_indicator(buf, buf_state, line)
    if buf_state.line_state[line] == LineState.LOADING then
        buf_state.line_state[line] = nil
        buf_state.loading_lines[line] = nil
        vim.api.nvim_buf_clear_namespace(buf, LOADING_NS, line, line + 1)
    end
end

---@param buf integer
---@param buf_state BufUiState
local function render_loading(buf, buf_state)
    if not next(buf_state.loading_lines) then
        stop_loading_timer(buf_state)
        return
    end

    local frame = LOADING_FRAMES[buf_state.loading_frame] or LOADING_FRAMES[1]
    buf_state.loading_frame = (buf_state.loading_frame % #LOADING_FRAMES) + 1

    vim.api.nvim_buf_clear_namespace(buf, LOADING_NS, 0, -1)
    for line, _ in pairs(buf_state.loading_lines) do
        vim.api.nvim_buf_set_extmark(buf, LOADING_NS, line, -1, {
            virt_text = { { loading_text(state.cfg.text.loading, frame), state.cfg.highlight.loading } },
            virt_text_pos = "eol",
            hl_mode = "combine",
        })
    end
end

---@param buf integer
---@param buf_state BufUiState
local function ensure_loading_timer(buf, buf_state)
    if buf_state.loading_timer then
        return
    end

    local timer = assert(vim.loop.new_timer())
    buf_state.loading_timer = timer
    timer:start(120, 120, vim.schedule_wrap(function()
        local current = M.state[buf]
        if not current or current.loading_timer ~= timer then
            return
        end

        if not state.visible or not vim.api.nvim_buf_is_loaded(buf) or not next(current.loading_lines) then
            stop_loading_timer(current)
            return
        end

        render_loading(buf, current)
    end))
end

---@param buf integer
---@param d CratesDiagnostic
---@return vim.Diagnostic
local function to_vim_diagnostic(buf, d)
    ---@type vim.Diagnostic
    return {
        bufnr = buf,
        lnum = d.lnum,
        end_lnum = d.end_lnum,
        col = d.col,
        end_col = d.end_col,
        severity = d.severity,
        message = d:message(state.cfg.diagnostic[d.kind]),
        source = "crates",
    }
end

---comment
---@param buf integer
---@param diagnostics CratesDiagnostic[]
---@param custom_diagnostics CratesDiagnostic[]
function M.display_diagnostics(buf, diagnostics, custom_diagnostics)
    if not state.visible then
        return
    end

    local buf_state = M.get_or_init(buf)
    for _, d in ipairs(diagnostics) do
        local vim_diagnostic = to_vim_diagnostic(buf, d)
        table.insert(buf_state.diagnostics, vim_diagnostic)
    end
    for _, d in ipairs(custom_diagnostics) do
        local vim_diagnostic = to_vim_diagnostic(buf, d)
        table.insert(buf_state.custom_diagnostics, vim_diagnostic)
    end

    vim.diagnostic.set(DIAGNOSTIC_NS, buf, buf_state.diagnostics, {})
    vim.diagnostic.set(CUSTOM_NS, buf, buf_state.custom_diagnostics, { virtual_text = false })
end

---@param buf integer
---@param infos CrateInfo[]
function M.display_crate_info(buf, infos)
    if not state.visible then
        return
    end

    local buf_state = M.get_or_init(buf)
    for _, info in ipairs(infos) do
        hide_loading_indicator(buf, buf_state, info.vers_line)

        local virt_text = {}
        if info.vers_match then
            table.insert(virt_text, {
                string.format(state.cfg.text[info.match_kind], info.vers_match.num),
                state.cfg.highlight[info.match_kind],
            })
        elseif info.match_kind == MatchKind.NOMATCH then
            table.insert(virt_text, {
                state.cfg.text.nomatch,
                state.cfg.highlight.nomatch,
            })
        end
        if info.vers_upgrade then
            table.insert(virt_text, {
                string.format(state.cfg.text.upgrade, info.vers_upgrade.num),
                state.cfg.highlight.upgrade,
            })
        end

        if not (info.vers_match or info.vers_upgrade) then
            table.insert(virt_text, {
                state.cfg.text.error,
                state.cfg.highlight.error,
            })
        end

        vim.api.nvim_buf_clear_namespace(buf, CUSTOM_NS, info.lines.s, info.lines.e)
        vim.api.nvim_buf_set_extmark(buf, CUSTOM_NS, info.vers_line, -1, {
            virt_text = virt_text,
            virt_text_pos = "eol",
            hl_mode = "combine",
        })
    end

    if not next(buf_state.loading_lines) then
        stop_loading_timer(buf_state)
    end
end

---@param buf integer
---@param crates TomlCrate[]
function M.display_loading(buf, crates)
    if not state.visible then
        return
    end

    local buf_state = M.get_or_init(buf)

    for _, crate in ipairs(crates) do
        local vers_line = crate.vers and crate.vers.line or crate.lines.s
        buf_state.line_state[vers_line] = LineState.LOADING
        buf_state.loading_lines[vers_line] = true
    end

    render_loading(buf, buf_state)
    ensure_loading_timer(buf, buf_state)
end

---@param buf integer
---@param buf_state BufUiState
---@param line integer
local function hide_search_indicator(buf, buf_state, line)
    if buf_state.line_state[line] == LineState.SEARCHING then
        buf_state.line_state[line] = nil
        vim.api.nvim_buf_clear_namespace(buf, CUSTOM_NS, line, line + 1)
    end
end

---@param buf integer
---@param line integer
---@return number?
function M.show_search_indicator(buf, line)
    if not state.visible then
        return
    end

    local buf_state = M.get_or_init(buf)
    if buf_state.search_transaction then
        local last_line = buf_state.search_transaction.line
        if last_line ~= line then
            hide_search_indicator(buf, buf_state, last_line)
        end
    end

    if buf_state.line_state[line] then
        return
    end

    local transaction = {
        line = line,
        id = math.random(),
    }
    buf_state.search_transaction = transaction
    buf_state.line_state[line] = LineState.SEARCHING

    vim.api.nvim_buf_set_extmark(buf, CUSTOM_NS, line, -1, {
        virt_text = { { state.cfg.text.searching, state.cfg.highlight.searching } },
        virt_text_pos = "eol",
        hl_mode = "combine",
    })

    return transaction.id
end

---Returns wether the transaction was cancelled
---@param buf integer
---@param transaction number
---@return boolean
function M.hide_search_indicator(buf, transaction)
    local buf_state = M.get_or_init(buf)
    local last_transaction = buf_state.search_transaction
    if not last_transaction or last_transaction.id ~= transaction then
        return true
    end

    local line = last_transaction.line
    hide_search_indicator(buf, buf_state, line)

    buf_state.search_transaction = nil

    return false
end

---@param buf integer
function M.clear(buf)
    local buf_state = M.state[buf]
    if buf_state then
        stop_loading_timer(buf_state)
    end

    M.state[buf] = nil

    vim.api.nvim_buf_clear_namespace(buf, CUSTOM_NS, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, LOADING_NS, 0, -1)
    vim.diagnostic.reset(CUSTOM_NS, buf)
    vim.diagnostic.reset(DIAGNOSTIC_NS, buf)
end

return M
