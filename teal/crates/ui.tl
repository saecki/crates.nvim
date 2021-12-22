local record M
    namespace: integer
    custom_diagnostics: {integer:{vim.diagnostic.Diagnostic}}
    diagnostic_namespace: integer
end

local core = require('crates.core')
local Crate = require('crates.toml').Crate
local CrateInfo = require('crates.diagnostic').CrateInfo

M.namespace = vim.api.nvim_create_namespace("crates.nvim") as integer
M.custom_diagnostics = {}
M.diagnostic_namespace = vim.api.nvim_create_namespace("crates.nvim.diagnostic") as integer

function M.display_diagnostics(buf: integer, diagnostics: {vim.diagnostic.Diagnostic})
    if not core.visible then return end

    vim.diagnostic.set(M.diagnostic_namespace, buf, diagnostics)
end

function M.display_crate_info(buf: integer, info: CrateInfo)
    if not core.visible then return end

    M.custom_diagnostics[buf] = M.custom_diagnostics[buf] or {}
    vim.list_extend(M.custom_diagnostics[buf], info.diagnostics)

    vim.diagnostic.set(M.namespace, buf, M.custom_diagnostics[buf], { virtual_text = false })
    vim.api.nvim_buf_clear_namespace(buf, M.namespace, info.lines.s, info.lines.e)
    vim.api.nvim_buf_set_extmark(buf, M.namespace, info.vers_line, -1, {
        virt_text = info.virt_text,
        virt_text_pos = "eol",
        hl_mode = "combine",
    })
end

function M.display_loading(buf: integer, crate: Crate)
    if not core.visible then return end

    local virt_text = { { core.cfg.text.loading, core.cfg.highlight.loading } }
    vim.api.nvim_buf_clear_namespace(buf, M.namespace, crate.lines.s, crate.lines.e)
    vim.api.nvim_buf_set_extmark(buf, M.namespace, crate.vers.line, -1, {
        virt_text = virt_text,
        virt_text_pos = "eol",
        hl_mode = "combine",
    })
end

function M.clear(buf: integer)
    M.custom_diagnostics[buf] = nil
    vim.api.nvim_buf_clear_namespace(buf, M.namespace, 0, -1)
    vim.diagnostic.reset(M.namespace, buf)
    vim.diagnostic.reset(M.diagnostic_namespace, buf)
end

return M
