local record M end

local state = require("crates.state")
local util = require("crates.util")

function M.check()
    vim.health.start("Checking required plugins")
    if util.lualib_installed("plenary") then
        vim.health.ok("plenary.nvim installed")
    else
        vim.health.error("plenary.nvim not found")
    end
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

    local num = 0
    for _, prg in ipairs(state.cfg.open_programs) do
        if util.binary_installed(prg) then
            vim.health.ok(string.format("%s installed", prg))
            num = num + 1
        end
    end

    if num == 0 then
        local programs = table.concat(state.cfg.open_programs, " ")
        vim.health.warn("none of the following are installed " .. programs)
    end
end

return M
