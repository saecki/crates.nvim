local record M
    run_queued_jobs: function()

    crate_jobs: {string:CrateJob}
    deps_jobs: {string:DepsJob}
    queued_jobs: {QueuedJob}
    num_requests: integer

    record CrateJob
        job: Job
        callbacks: {function(Crate, boolean)}
    end

    record DepsJob
        job: Job
        callbacks: {function({Dependency}, boolean)}
    end

    record QueuedJob
        kind: JobKind
        name: string

        crate_callbacks: {function(Crate|nil, boolean)}

        version: string
        deps_callbacks: {function({Dependency}|nil, boolean)}
    end

    enum JobKind
        "crate"
        "deps"
    end
end

local semver = require("crates.semver")
local state = require("crates.state")
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
M.deps_jobs = {}
M.queued_jobs = {}
M.num_requests = 0


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

local function request_job(url: string, on_exit: function(j: Job, code: integer, signal: integer)): Job
    return Job:new {
        command = "curl",
        args = { unpack(state.cfg.curl_args), "-A", USERAGENT, url },
        on_exit = vim.schedule_wrap(on_exit) as function(Job, integer, integer),
    }
end

local function enqueue_crate_job(name: string, callbacks: {function(Crate|nil, boolean)})
    for _,j in ipairs(M.queued_jobs) do
        if j.kind == "crate" and j.name == name then
            vim.list_extend(j.crate_callbacks, callbacks)
            return
        end
    end

    table.insert(M.queued_jobs, {
        kind = "crate",
        name = name,
        crate_callbacks = callbacks,
    })
end

local function enqueue_deps_job(name: string, version: string, callbacks: {function({Dependency}|nil, boolean)})
    for _,j in ipairs(M.queued_jobs) do
        if j.kind == "deps" and j.name == name and j.version == version then
            vim.list_extend(j.deps_callbacks, callbacks)
            return
        end
    end

    table.insert(M.queued_jobs, {
        kind = "deps",
        name = name,
        version = version,
        deps_callbacks = callbacks,
    })
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
        updated = DateTime.parse_rfc_3339(c.updated_at as string),
        downloads = c.downloads as integer,
        homepage = c.homepage as string,
        documentation = c.documentation as string,
        repository = c.repository as string,
        categories = {},
        keywords = {},
        versions = {},
    }

    for _,ct_id in ipairs(c.categories as {{string:any}}) do
        for _,ct in ipairs(json.categories as {{string:any}}) do
            if ct.id == ct_id then
                table.insert(crate.categories, ct.category as string)
            end
        end
    end

    for _,kw_id in ipairs(c.keywords as {{string:any}}) do
        for _,kw in ipairs(json.keywords as {{string:any}}) do
            if kw.id == kw_id then
                table.insert(crate.keywords, kw.keyword as string)
            end
        end
    end

    for _,v in ipairs(json.versions as {table}) do
        if v.num then
            local version: Version = {
                num = v.num as string,
                features = Features.new({}),
                yanked = v.yanked as boolean,
                parsed = semver.parse_version(v.num as string),
                created = DateTime.parse_rfc_3339(v.created_at as string)
            }

            for n,m in pairs(v.features as {string:{string}}) do
                table.sort(m)
                version.features:insert({
                    name = n,
                    members = m,
                })
            end

            -- add optional dependency members as features
            for _,f in ipairs(version.features.list) do
                for _,m in ipairs(f.members) do
                    -- don't add dependency features
                    if not string.find(m, "/") and not version.features:get_feat(m) then
                        version.features:insert({
                            name = m,
                            members = {},
                        })
                    end
                end
            end

            -- sort features alphabetically
            version.features:sort()

            -- add missing default feature
            if not version.features.list[1] or not (version.features.list[1].name == "default") then
                version.features:insert({
                    name = "default",
                    members = {},
                })
            end

            table.insert(crate.versions, version)
        end
    end


    return crate
end

local function fetch_crate(name: string, callbacks: {function(Crate|nil, boolean)})
    local existing = M.crate_jobs[name]
    if existing then
        vim.list_extend(existing.callbacks, callbacks)
        return
    end

    if M.num_requests >= state.cfg.max_parallel_requests then
        enqueue_crate_job(name, callbacks)
        return
    end

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
        M.num_requests = M.num_requests - 1

        M.run_queued_jobs()
    end

    local job = request_job(url, on_exit)
    M.num_requests = M.num_requests + 1
    M.crate_jobs[name] = {
        job = job,
        callbacks = callbacks,
    }
    job:start()
end

function M.fetch_crate(name: string): Crate, boolean
    return coroutine.yield(function(resolve: function(Crate, boolean))
        fetch_crate(name, {resolve})
    end) as (Crate, boolean)
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
                    text = d.req as string,
                    reqs = semver.parse_requirements(d.req as string),
                },
            }
            table.insert(dependencies, dependency)
        end
    end

    return dependencies
end

local function fetch_deps(name: string, version: string, callbacks: {function({Dependency}, boolean)})
    local jobname = name .. ":" .. version
    local existing = M.deps_jobs[jobname]
    if existing then
        vim.list_extend(existing.callbacks, callbacks)
        return
    end

    if M.num_requests >= state.cfg.max_parallel_requests then
        enqueue_deps_job(name, version, callbacks)
        return
    end

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

        M.num_requests = M.num_requests - 1
        M.deps_jobs[jobname] = nil

        M.run_queued_jobs()
    end

    local job = request_job(url, on_exit)
    M.num_requests = M.num_requests + 1
    M.deps_jobs[jobname] = {
        job = job,
        callbacks = callbacks,
    }
    job:start()
end

function M.fetch_deps(name: string, version: string): {Dependency}, boolean
    return coroutine.yield(function(resolve: function({Dependency}, boolean))
        fetch_deps(name, version, {resolve})
    end) as ({Dependency}, boolean)
end


function M.is_fetching_crate(name: string): boolean
    return M.crate_jobs[name] ~= nil
end

function M.is_fetching_deps(name: string, version: string): boolean
    return M.deps_jobs[name .. ":" .. version] ~= nil
end

local function add_crate_callback(name: string, callback: function(Crate, boolean))
    table.insert(
        M.crate_jobs[name].callbacks,
        callback
    )
end

function M.await_crate(name: string): Crate, boolean
    return coroutine.yield(function(resolve: function(Crate, boolean))
        add_crate_callback(name, resolve)
    end) as (Crate, boolean)
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

function M.run_queued_jobs()
    if #M.queued_jobs == 0 then
        return
    end

    local job = table.remove(M.queued_jobs, 1)
    if job.kind == "crate" then
        fetch_crate(job.name, job.crate_callbacks)
    elseif job.kind == "deps" then
        fetch_deps(job.name, job.version, job.deps_callbacks)
    end
end

function M.cancel_jobs()
    for _,r in pairs(M.crate_jobs) do
        r.job:shutdown(1, 1)
    end
    for _,r in pairs(M.deps_jobs) do
        r.job:shutdown(1, 1)
    end
    M.crate_jobs = {}
    M.deps_jobs = {}
end

return M
