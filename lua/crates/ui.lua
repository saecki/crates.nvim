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

---@class SearchTransaction
---@field id number
---@field line integer

---@enum LineState
local LineState = {
    SEARCHING = 1,
    LOADING = 2,
    UPDATE = 3,
}

---@param buf integer
---@return BufUiState
function M.get_or_init(buf)
    local buf_state  = M.state[buf] or {
        custom_diagnostics = {},
        diagnostics = {},
        line_state = {},
    }
    M.state[buf] = buf_state
    return buf_state
end

---@type integer
local CUSTOM_NS = vim.api.nvim_create_namespace("crates.nvim")
---@type integer
local DIAGNOSTIC_NS = vim.api.nvim_create_namespace("crates.nvim.diagnostic")

---@param d CratesDiagnostic
---@return vim.Diagnostic
local function to_vim_diagnostic(d)
    ---@type vim.Diagnostic
    return {
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
        local vim_diagnostic = to_vim_diagnostic(d)
        table.insert(buf_state.diagnostics, vim_diagnostic)
    end
    for _, d in ipairs(custom_diagnostics) do
        local vim_diagnostic = to_vim_diagnostic(d)
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

    for _, info in ipairs(infos) do
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

        local virt_text = { { state.cfg.text.loading, state.cfg.highlight.loading } }
        vim.api.nvim_buf_set_extmark(buf, CUSTOM_NS, vers_line, -1, {
            virt_text = virt_text,
            virt_text_pos = "eol",
            hl_mode = "combine",
        })
    end
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
    M.state[buf] = nil

    vim.api.nvim_buf_clear_namespace(buf, CUSTOM_NS, 0, -1)
    vim.diagnostic.reset(CUSTOM_NS, buf)
    vim.diagnostic.reset(DIAGNOSTIC_NS, buf)
end

return M
