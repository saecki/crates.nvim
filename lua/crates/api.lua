---@class Version
---@field num string
---@field yanked boolean
---@field parsed SemVer

local job = require("plenary.job")
local semver = require("crates.semver")

local M = {}

local endpoint = "https://crates.io/api/v1"
local useragent = vim.fn.shellescape("crates.nvim (https://github.com/saecki/crates.nvim)")

local running_jobs = {}

---@param name string
---@param callback function(versions Version[])
function M.fetch_crate_versions(name, callback)
    if running_jobs[name] then
        return
    end

    local url = string.format("%s/crates/%s/versions", endpoint, name)
    local resp = nil

    local function parse_json()
        if not resp then
            callback(nil)
            return
        end

        local success, data = pcall(vim.fn.json_decode, resp)
        if not success then
            data = nil
        end

        local versions = {}
        if data and type(data) == "table" and data.versions then
            for _,v in ipairs(data.versions) do
                if v.num then
                    local version = {
                        num = v.num,
                        yanked = v.yanked,
                        parsed = semver.parse_version(v.num),
                    }
                    table.insert(versions, version)
                end
            end
        end

        callback(versions)
    end

    local function on_exit(j, code, _)
        if code == 0 then
            resp = table.concat(j:result(), "\n")
        end

        vim.schedule(parse_json)

        running_jobs[name] = nil
    end

    local j = job:new {
        command = "curl",
        args = { "-sLA", useragent, url },
        on_exit = vim.schedule_wrap(on_exit),
    }

    running_jobs[name] = j

    j:start()
end

return M