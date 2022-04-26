local record M end

local util = require("crates.util")

local health_start = vim.fn["health#report_start"]
local health_ok = vim.fn["health#report_ok"]
local health_warn = vim.fn["health#report_warn"]
local health_error = vim.fn["health#report_error"]

function M.check()
    health_start("Checking for required plugins")
    if util.lualib_installed("plenary") then
        health_ok("plenary.nvim installed")
    else
        health_error("plenary.nvim not found")
    end
    if util.lualib_installed("null-ls") then
        health_ok("null-ls.nvim installed")
    else
        health_warn("null-ls.nvim not found")
    end

    health_start("Checking for external dependencies")
    if util.binary_installed("curl") then
        health_ok("curl installed")
    else
        health_error("curl not found")
    end

    if util.binary_installed("xdg-open") then
        health_ok("xdg-open installed")
    elseif util.binary_installed("open") then
        health_ok("open installed")
    else
        health_warn("xdg-open or open not found")
    end
end

return M
