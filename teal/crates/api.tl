local record M
    running_jobs: {string:Job}
    record Version
        num: string
        features: Features
        yanked: boolean
        parsed: SemVer
        created: DateTime
    end

    record Features
        {Feature}
    end

    record Feature
        name: string
        members: {string}
    end
end

local Version = M.Version
local Features = M.Features
local Feature = M.Feature
local Job = require('plenary.job')
local semver = require('crates.semver')
local SemVer = semver.SemVer
local DateTime = require('crates.time').DateTime

local endpoint = "https://crates.io/api/v1"
local useragent = vim.fn.shellescape("crates.nvim (https://github.com/saecki/crates.nvim)") as string

M.running_jobs = {}


function Features.new(obj: table): Features
    return setmetatable(obj as Features, { __index = Features })
end

function Features:get_feat(name: string): Feature|nil, integer|nil
    for i,f in ipairs(self) do
        if f.name == name then
            return f, i
        end
    end

    return nil, nil
end

function M.fetch_crate_versions(name: string, callback: function({Version}))
    if M.running_jobs[name] then
        return
    end

    local url = string.format("%s/crates/%s/versions", endpoint, name)
    local resp: string = nil

    local function parse_json()
        if not resp then
            callback(nil)
            return
        end

        local success, data = pcall(vim.fn.json_decode, resp) as (boolean, {string:{table}})
        if not success then
            data = nil
        end

        local versions: {Version} = {}
        if data and type(data) == "table" and data.versions then
            for _,v in ipairs(data.versions) do
                if v.num then
                    local version = {
                        num = v.num,
                        features = Features.new {},
                        yanked = v.yanked,
                        parsed = semver.parse_version(v.num as string),
                        created = DateTime.parse_rfc_3339(v.created_at as string)
                    }

                    for n,m in pairs(v.features as {string:{string}}) do
                        table.sort(m)
                        table.insert(version.features, {
                            name = n,
                            members = m,
                        })
                    end

                    -- add optional dependency members as features
                    for _,f in ipairs(version.features) do
                        for _,m in ipairs(f.members) do
                            if not version.features:get_feat(m) then
                                table.insert(version.features, {
                                    name = m,
                                    members = {},
                                })
                            end
                        end
                    end

                    -- sort features alphabetically
                    table.sort(version.features, function (a: Feature, b: Feature): boolean
                        if a.name == "default" then
                            return true
                        elseif b.name == "default" then
                            return false
                        else
                            return a.name < b.name
                        end
                    end)

                    -- add missing default feature
                    if not version.features[1] or not (version.features[1].name == "default") then
                        for i=#version.features, 1, -1 do
                            version.features[i + 1] = version.features[i]
                        end

                        version.features[1] = {
                            name = "default",
                            members = {},
                        }
                    end

                    table.insert(versions, version)
                end
            end
        end

        callback(versions)
    end

    local function on_exit(j: Job, code: integer, _: integer)
        if code == 0 then
            resp = table.concat(j:result(), "\n")
        end

        vim.schedule(parse_json)

        M.running_jobs[name] = nil
    end

    local j = Job:new {
        command = "curl",
        args = { "-sLA", useragent, url },
        on_exit = vim.schedule_wrap(on_exit) as function(Job, integer, integer),
    }

    M.running_jobs[name] = j

    j:start()
end

return M
