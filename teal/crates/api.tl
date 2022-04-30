local record M
    crate_jobs: {string:CrateJob}
    vers_jobs: {string:VersJob}
    deps_jobs: {string:DepsJob}

    record CrateJob
        job: Job
        callbacks: {function(Crate, boolean)}
    end

    record VersJob
        job: Job
        callbacks: {function({Version}, boolean)}
    end

    record DepsJob
        job: Job
        callbacks: {function({Dependency}, boolean)}
    end
end

local semver = require("crates.semver")
local time = require("crates.time")
local DateTime = time.DateTime
local types = require("crates.types")
local Dependency = types.Dependency
local Crate = types.Crate
local Features = types.Features
local Version = types.Version
local Job = require("plenary.job")

local ENDPOINT = "https://crates.io/api/v1"
local USERAGENT = vim.fn.shellescape("crates.nvim (https://github.com/saecki/crates.nvim)") as string
local JSON_DECODE_OPTS: vim.json.DecodeOpts = { luanil = { object = true, array = true } }

M.crate_jobs = {}
M.vers_jobs = {}
M.deps_jobs = {}


local function parse_json(json_str: string): table
    if not json_str then
        return
    end

    local success, json = pcall(vim.json.decode, json_str, JSON_DECODE_OPTS) as (boolean, {string:{table}})
    if not success then
        return
    end

    if json and type(json) == "table" then
        return json
    end
end


function M.parse_crate(json_str: string): Crate|nil
    local json = parse_json(json_str)
    if not (json and json.crate) then
        return
    end

    local c = json.crate as {string:any}
    local crate: Crate = {
        name = c.id as string,
        description = c.description as string,
        created = DateTime.parse_rfc_3339(c.created_at as string),
        downloads = c.downloads as integer,
        homepage = c.homepage as string,
        documentation = c.documentation as string,
        repository = c.repository as string,
    }
    return crate
end

local function fetch_crate(name: string, callback: function(Crate|nil, boolean))
    if M.crate_jobs[name] then
        return
    end

    local callbacks = { callback }
    local url = string.format("%s/crates/%s", ENDPOINT, name)

    local function on_exit(j: Job, code: integer, signal: integer)
        local cancelled = signal ~= 0

        local json: string = nil
        if code == 0 then
            json = table.concat(j:result(), "\n")
        end

        local crate: Crate = nil
        if not cancelled then
            crate = M.parse_crate(json)
        end
        for _,c in ipairs(callbacks) do
            c(crate, cancelled)
        end

        M.crate_jobs[name] = nil
    end

    local j = Job:new {
        command = "curl",
        args = { "-sLA", USERAGENT, url },
        on_exit = vim.schedule_wrap(on_exit) as function(Job, integer, integer),
    }

    M.crate_jobs[name] = {
        job = j,
        callbacks = callbacks,
    }

    j:start()
end

function M.fetch_crate(name: string): Crate, boolean
    return coroutine.yield(function(resolve: function(Crate, boolean))
        fetch_crate(name, resolve)
    end) as (Crate, boolean)
end


function M.parse_vers(json_str: string): {Version}|nil
    local json = parse_json(json_str)
    if not (json and json.versions) then
        return
    end

    local versions: {Version} = {}
    for _,v in ipairs(json.versions as {table}) do
        if v.num then
            local version: Version = {
                num = v.num as string,
                features = Features.new {},
                yanked = v.yanked as boolean,
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
            version.features:sort()

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

    return versions
end

local function fetch_vers(name: string, callback: function({Version}, boolean))
    if M.vers_jobs[name] then
        return
    end

    local callbacks = { callback }
    local url = string.format("%s/crates/%s/versions", ENDPOINT, name)

    local function on_exit(j: Job, code: integer, signal: integer)
        local cancelled = signal ~= 0

        local json: string = nil
        if code == 0 then
            json = table.concat(j:result(), "\n")
        end

        local versions: {Version} = nil
        if not cancelled then
            versions = M.parse_vers(json)
        end
        for _,c in ipairs(callbacks) do
            c(versions, cancelled)
        end

        M.vers_jobs[name] = nil
    end

    local j = Job:new {
        command = "curl",
        args = { "-sLA", USERAGENT, url },
        on_exit = vim.schedule_wrap(on_exit) as function(Job, integer, integer),
    }

    M.vers_jobs[name] = {
        job = j,
        callbacks = callbacks,
    }

    j:start()
end

function M.fetch_vers(name: string): {Version}, boolean
    return coroutine.yield(function(resolve: function({Version}, boolean))
        fetch_vers(name, resolve)
    end) as ({Version}, boolean)
end


function M.parse_deps(json_str: string): {Dependency}|nil
    local json = parse_json(json_str)
    if not (json and json.dependencies) then
        return
    end

    local dependencies: {Dependency} = {}
    for _,d in ipairs(json.dependencies as {table}) do
        if d.crate_id then
            local dependency: Dependency = {
                name = d.crate_id as string,
                opt = d.optional as boolean or false,
                kind = d.kind as Dependency.Kind or "normal",
                vers = {
                    text = d.req,
                    reqs = semver.parse_requirements(d.req as string),
                },
            }
            table.insert(dependencies, dependency)
        end
    end

    return dependencies
end

local function fetch_deps(name: string, version: string, callback: function({Dependency}, boolean))
    local jobname = name .. ":" .. version
    if M.deps_jobs[jobname] then
        return
    end

    local callbacks = { callback }
    local url = string.format("%s/crates/%s/%s/dependencies", ENDPOINT, name, version)

    local function on_exit(j: Job, code: integer, signal: integer)
        local cancelled = signal ~= 0

        local json: string = nil
        if code == 0 then
            json = table.concat(j:result(), "\n")
        end

        local deps: {Dependency} = nil
        if not cancelled then
            deps = M.parse_deps(json)
        end
        for _,c in ipairs(callbacks) do
            c(deps, cancelled)
        end

        M.deps_jobs[jobname] = nil
    end

    local j = Job:new {
        command = "curl",
        args = { "-sLA", USERAGENT, url },
        on_exit = vim.schedule_wrap(on_exit) as function(Job, integer, integer),
    }

    M.deps_jobs[jobname] = {
        job = j,
        callbacks = callbacks,
    }

    j:start()
end

function M.fetch_deps(name: string, version: string): {Dependency}, boolean
    return coroutine.yield(function(resolve: function({Dependency}, boolean))
        fetch_deps(name, version, resolve)
    end) as ({Dependency}, boolean)
end

function M.is_fetching_vers(name: string): boolean
    return M.vers_jobs[name] ~= nil
end

function M.is_fetching_deps(name: string, version: string): boolean
    return M.deps_jobs[name .. ":" .. version] ~= nil
end

local function add_vers_callback(name: string, callback: function({Version}, boolean))
    table.insert(
        M.vers_jobs[name].callbacks,
        callback
    )
end

function M.await_vers(name: string): {Version}, boolean
    return coroutine.yield(function(resolve: function({Version}, boolean))
        add_vers_callback(name, resolve)
    end) as ({Version}, boolean)
end

local function add_deps_callback(name: string, version: string, callback: function({Dependency}, boolean))
    table.insert(
        M.deps_jobs[name .. ":" .. version].callbacks,
        callback
    )
end

function M.await_deps(name: string, version: string): {Dependency}, boolean
    return coroutine.yield(function(resolve: function({Dependency}, boolean))
        add_deps_callback(name, version, resolve)
    end) as ({Dependency}, boolean)
end

function M.cancel_jobs()
    for _,r in pairs(M.vers_jobs) do
        r.job:shutdown(1, 1)
    end
    for _,r in pairs(M.deps_jobs) do
        r.job:shutdown(1, 1)
    end
    M.vers_jobs = {}
    M.deps_jobs = {}
end

return M
