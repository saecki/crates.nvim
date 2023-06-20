local record M end

local state = require("crates.state")
local util = require("crates.util")

local health = vim.health or require "health"
local health_start = health.start or health.report_start
local health_ok = health.ok or health.report_ok
local health_warn = health.warn or health.report_warn
local health_error = health.error or health.report_error

function M.check()
    health_start("Checking required plugins")
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

    health_start("Checking external dependencies")
    if util.binary_installed("curl") then
        health_ok("curl installed")
    else
        health_error("curl not found")
    end

    local num = 0
    for _, prg in ipairs(state.cfg.open_programs) do
        if util.binary_installed(prg) then
            health_ok(string.format("%s installed", prg))
            num = num + 1
        end
    end

    if num == 0 then
        local programs = table.concat(state.cfg.open_programs, " ")
        health_warn("none of the following are installed " .. programs)
    end
end

return M
