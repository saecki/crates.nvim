local M = {}

local state = require("crates.state")
local util = require("crates.util")

function M.check()
    vim.health.start("Checking plugins")
    if util.lualib_installed("null-ls") then
        vim.health.ok("null-ls.nvim installed")
    else
        vim.health.info("null-ls.nvim not found")
    end

    vim.health.start("Checking external dependencies")
    if util.binary_installed("curl") then
        vim.health.ok("curl installed")
    else
        vim.health.error("curl not found")
    end
end

return M
