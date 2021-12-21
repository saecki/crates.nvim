local record M end

local health_start = vim.fn["health#report_start"]
local health_ok = vim.fn["health#report_ok"]
local health_error = vim.fn["health#report_error"]
local is_win = vim.api.nvim_call_function("has", { "win32" }) == 1


local function lualib_installed(name: string): boolean
    local ok, _ = pcall(require as function(string): (any), name)
    return ok
end

local function binary_installed(name: string): boolean
    if is_win then
        name = name .. ".exe"
    end

    return vim.fn.executable(name) == 1
end

function M.check()
    health_start("Checking for required plugins")
    if lualib_installed("plenary") then
        health_ok("plenary.nvim installed")
    else
        health_error("plenary.nvim not found")
    end
    
    health_start("Checking for external dependencies")
    if binary_installed("curl") then
        health_ok("curl installed")
    else
        health_error("curl not found")
    end
end

return M
