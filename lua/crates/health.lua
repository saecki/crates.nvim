local M = {}

local state = require("crates.state")

local IS_WIN = vim.api.nvim_call_function("has", { "win32" }) == 1

---@param name string
---@return boolean
local function lualib_installed(name)
    local ok = pcall(require, name)
    return ok
end

---comment
---@param name string
---@return boolean
local function binary_installed(name)
    if IS_WIN then
        name = name .. ".exe"
    end

    return vim.fn.executable(name) == 1
end

function M.check()
    if not state.cfg then
        vim.health.info("skipping health check, setup hasn't been called")
        return
    end

    vim.health.start("Checking plugins")
    if lualib_installed("null-ls") then
        vim.health.ok("null-ls.nvim installed")
    elseif state.cfg.null_ls.enabled then
        vim.health.warn("null-ls.nvim not found, but `null_ls.enabled` is set")
    end
    if state.cfg.lsp.enabled and state.cfg.lsp.actions and state.cfg.null_ls.enabled then
        vim.health.warn("lsp actions and null-ls.nvim actions are enabled, only one should be necessary")
    end

    if lualib_installed("neoconf") then
        vim.health.ok("neoconf.nvim installed")
    elseif state.cfg.neoconf.enabled then
        vim.health.warn("neoconf.nvim not found, but `neoconf.enabled` is set")
    end

    if lualib_installed("cmp") then
        vim.health.ok("nvim-cmp installed")
    elseif state.cfg.completion.cmp.enabled then
        vim.health.warn("nvim-cmp not found, but `completion.cmp.enabled` is set")
    end

    if lualib_installed("coq") then
        vim.health.ok("coq_nvim installed")
    elseif state.cfg.completion.coq.enabled then
        vim.health.warn("coq_nvim not found, but `completion.coq.enabled` is set")
    end

    if state.cfg.lsp.enabled and state.cfg.lsp.completion then
        if state.cfg.completion.cmp.enabled then
            vim.health.warn("lsp completion and nvim-cmp completion is enabled, only one should be necessary")
        end
        if state.cfg.completion.coq.enabled then
            vim.health.warn("lsp completion and coq_nvim completion is enabled, only one should be necessary")
        end
    end
    if state.cfg.completion.cmp.enabled and state.cfg.completion.coq.enabled then
        vim.health.warn("nvim-cmp and coq_nvim completion are enabled, only one should be necessary")
    end

    vim.health.start("Checking external dependencies")
    if binary_installed("curl") then
        vim.health.ok("curl installed")
    else
        vim.health.error("curl not found")
    end
end

return M
