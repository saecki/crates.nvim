local record M
    custom_diagnostics: {integer:{vim.diagnostic.Diagnostic}}
    diagnostics: {integer:{vim.diagnostic.Diagnostic}}
end

local state = require("crates.state")
local toml = require("crates.toml")
local types = require("crates.types")
local CrateInfo = types.CrateInfo
local Diagnostic = types.Diagnostic
local Version = types.Version

local CUSTOM_NS = vim.api.nvim_create_namespace("crates.nvim") as integer
local DIAGNOSTIC_NS = vim.api.nvim_create_namespace("crates.nvim.diagnostic") as integer

M.custom_diagnostics = {}
M.diagnostics = {}

local function to_vim_diagnostic(d: Diagnostic): vim.diagnostic.Diagnostic
    local diag: vim.diagnostic.Diagnostic = {
        lnum = d.lnum,
        end_lnum = d.end_lnum,
        col = d.col,
        end_col = d.end_col,
        severity = d.severity,
        message = state.cfg.diagnostic[d.kind],
        source = "crates",
    }
    return diag
end

function M.display_diagnostics(buf: integer, diagnostics: {Diagnostic})
    if not state.visible then return end

    M.diagnostics[buf] = M.diagnostics[buf] or {}
    local vim_diagnostics = vim.tbl_map(to_vim_diagnostic, diagnostics)
    vim.list_extend(M.diagnostics[buf], vim_diagnostics)

    vim.diagnostic.set(DIAGNOSTIC_NS, buf, M.diagnostics[buf])
end

function M.display_crate_info(buf: integer, info: CrateInfo, diagnostics: {Diagnostic})
    if not state.visible then return end

    M.custom_diagnostics[buf] = M.custom_diagnostics[buf] or {}
    local vim_diagnostics = vim.tbl_map(to_vim_diagnostic, diagnostics)
    vim.list_extend(M.custom_diagnostics[buf], vim_diagnostics)

    local virt_text = {}
    if info.vers_match then
        local match = info.vers_match as Version
        table.insert(virt_text, {
             string.format(state.cfg.text[info.match_kind], match.num),
             state.cfg.highlight[info.match_kind],
        })
    elseif info.match_kind == "nomatch" then
        table.insert(virt_text, {
             state.cfg.text.nomatch,
             state.cfg.highlight.nomatch,
        })
    end
    if info.vers_upgrade then
        local upgrade = info.vers_upgrade as Version
        table.insert(virt_text, {
             string.format(state.cfg.text.upgrade, upgrade.num),
             state.cfg.highlight.upgrade,
        })
    end

    if not (info.vers_match or info.vers_upgrade) then
        table.insert(virt_text, {
             state.cfg.text.error,
             state.cfg.highlight.error,
        })
    end

    vim.diagnostic.set(CUSTOM_NS, buf, M.custom_diagnostics[buf], { virtual_text = false })
    vim.api.nvim_buf_clear_namespace(buf, CUSTOM_NS, info.lines.s, info.lines.e)
    vim.api.nvim_buf_set_extmark(buf, CUSTOM_NS, info.vers_line, -1, {
        virt_text = virt_text,
        virt_text_pos = "eol",
        hl_mode = "combine",
    })
end

function M.display_loading(buf: integer, crate: toml.Crate)
    if not state.visible then return end

    local virt_text = { { state.cfg.text.loading, state.cfg.highlight.loading } }
    vim.api.nvim_buf_clear_namespace(buf, CUSTOM_NS, crate.lines.s, crate.lines.e)
    local vers_line = crate.vers and crate.vers.line or crate.lines.s
    vim.api.nvim_buf_set_extmark(buf, CUSTOM_NS, vers_line, -1, {
        virt_text = virt_text,
        virt_text_pos = "eol",
        hl_mode = "combine",
    })
end

function M.clear(buf: integer)
    M.custom_diagnostics[buf] = nil
    M.diagnostics[buf] = nil

    vim.api.nvim_buf_clear_namespace(buf, CUSTOM_NS, 0, -1)
    vim.diagnostic.reset(CUSTOM_NS, buf)
    vim.diagnostic.reset(DIAGNOSTIC_NS, buf)
end

return M
