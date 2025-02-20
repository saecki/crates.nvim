local semver = require("crates.semver")
local state = require("crates.state")
local time = require("crates.time")
local DateTime = time.DateTime
local types = require("crates.types")
local ApiFeatures = types.ApiFeatures
local ApiDependencyKind = types.ApiDependencyKind

local M = {
    ---@type table<string,CrateJob>
    crate_jobs = {},
    ---@type table<string,SearchJob>
    search_jobs = {},
    ---@type QueuedCrateJob[]
    crate_queue = {},
    ---@type QueuedSearchJob[]
    search_queue = {},
    ---@type integer
    num_requests = 0,
}

---@class Job
---@field handle uv.uv_process_t?
---@field was_cancelled boolean?

---@class CrateJob
---@field jobs { [1]: Job, [2]: Job }
---@field callbacks fun(crate: ApiCrate?, cancelled: boolean)[]

---@class SearchJob
---@field job Job
---@field callbacks fun(search: ApiCrateSummary[]?, cancelled: boolean)[]

---@class QueuedCrateJob
---@field name string
---@field callbacks fun(crate: ApiCrate?, cancelled: boolean)[]

---@class QueuedSearchJob
---@field name string
---@field callbacks fun(search: ApiCrateSummary[]?, cancelled: boolean)[]

local SIGTERM = 15
local API_ENDPOINT = "https://crates.io/api/v1"
local SPARSE_INDEX_ENDPOINT = "https://index.crates.io"
---@type string
local USERAGENT = vim.fn.shellescape("crates.nvim (https://github.com/saecki/crates.nvim)")

local DEPENDENCY_KIND_MAP = {
    ["normal"] = ApiDependencyKind.NORMAL,
    ["build"] = ApiDependencyKind.BUILD,
    ["dev"] = ApiDependencyKind.DEV,
}

---@class vim.json.DecodeOpts
---@class DecodeOpts
---@field luanil Luanil

---@class Luanil
---@field object boolean
---@field array boolean

---@type vim.json.DecodeOpts
local JSON_DECODE_OPTS = { luanil = { object = true, array = true } }


---comment
---@param json_str string
---@return table
function M.parse_json(json_str)
    ---@type any
    local json = vim.json.decode(json_str, JSON_DECODE_OPTS)
    assert(type(json) == "table")
    return json
end

---@param url string
---@param on_exit fun(data: string?, cancelled: boolean)
---@return Job?
local function start_job(url, on_exit)
    ---@type Job
    local job = {}
    ---@type uv.uv_pipe_t
    local stdout = assert(vim.loop.new_pipe())

    ---@type string?
    local stdout_str = nil

    local opts = {
        args = { unpack(state.cfg.curl_args), "-A", USERAGENT, url },
        stdio = { nil, stdout, nil },
    }
    local handle, _pid
    ---@param code integer
    ---@param _signal integer
    ---@type uv.uv_process_t, integer
    handle, _pid = vim.loop.spawn("curl", opts, function(code, _signal)
        handle:close()

        local success = code == 0

        ---@type uv.uv_check_t
        local check = assert(vim.loop.new_check())
        check:start(function()
            if not stdout:is_closing() then
                return
            end
            check:stop()

            vim.schedule(function()
                local data = success and stdout_str or nil
                on_exit(data, job.was_cancelled)
            end)
        end)
    end)

    if not handle then
        return nil
    end

    local accum = {}
    stdout:read_start(function(err, data)
        if err then
            stdout:read_stop()
            stdout:close()
            return
        end

        if data ~= nil then
            table.insert(accum, data)
        else
            stdout_str = table.concat(accum)
            stdout:read_stop()
            stdout:close()
        end
    end)

    job.handle = handle
    return job
end

---@param job Job
local function kill_job(job)
    if job.handle then
        job.handle:kill(SIGTERM)
    end
end

---@param name string
---@param callbacks fun(crate: ApiCrate?, cancelled: boolean)[]
local function enqueue_crate_job(name, callbacks)
    for _, j in ipairs(M.crate_queue) do
        if j.name == name then
            vim.list_extend(j.callbacks, callbacks)
            return
        end
    end

    table.insert(M.crate_queue, {
        name = name,
        callbacks = callbacks,
    })
end

---@param name string
---@param callbacks fun(search: ApiCrateSummary[]?, cancelled: boolean)[]
local function enqueue_search_job(name, callbacks)
    for _, j in ipairs(M.search_queue) do
        if j.name == name then
            vim.list_extend(j.callbacks, callbacks)
            return
        end
    end

    table.insert(M.search_queue, {
        name = name,
        callbacks = callbacks,
    })
end

---@param json_str string
---@return ApiCrateSummary[]?
function M.parse_search(json_str)
    local json = M.parse_json(json_str)
    if not (json and json.crates) then
        return
    end

    ---@type ApiCrateSummary[]
    local search = {}
    ---@diagnostic disable-next-line: no-unknown
    for _, c in ipairs(json.crates) do
        ---@type ApiCrateSummary
        local result = {
            name = c.name,
            description = c.description,
            newest_version = c.newest_version,
        }
        table.insert(search, result)
    end

    return search
end

---@param name string
---@param callbacks fun(search: ApiCrateSummary[]?, cancelled: boolean)[]
local function fetch_search(name, callbacks)
    local existing = M.search_jobs[name]
    if existing then
        vim.list_extend(existing.callbacks, callbacks)
        return
    end

    if M.num_requests >= state.cfg.max_parallel_requests then
        enqueue_search_job(name, callbacks)
        return
    end

    local url = string.format(
        "%s/crates?q=%s&per_page=%s",
        API_ENDPOINT,
        name,
        state.cfg.completion.crates.max_results
    )

    ---@param json_str string?
    ---@param cancelled boolean
    local function on_exit(json_str, cancelled)
        ---@type ApiCrateSummary[]?
        local search
        if not cancelled and json_str then
            local ok, s = pcall(M.parse_search, json_str)
            if ok then
                search = s
            end
        end
        for _, c in ipairs(callbacks) do
            c(search, cancelled)
        end

        M.search_jobs[name] = nil
        M.num_requests = M.num_requests - 1

        M.run_queued_jobs()
    end

    local job = start_job(url, on_exit)
    if job then
        M.num_requests = M.num_requests + 1
        M.search_jobs[name] = {
            job = job,
            callbacks = callbacks,
        }
    else
        for _, c in ipairs(callbacks) do
            c(nil, false)
        end
    end
end

---@param name string
---@return ApiCrateSummary[]?, boolean
function M.fetch_search(name)
    ---@param resolve fun(search: ApiCrateSummary[]?, cancelled: boolean)
    return coroutine.yield(function(resolve)
        fetch_search(name, { resolve })
    end)
end

---@param a ApiFeature
---@param b ApiFeature
---@return boolean
local function sort_features(a, b)
    if a.name == "default" then
        return true
    elseif b.name == "default" then
        return false
    else
        return a.name < b.name
    end
end

---@param a string
---@param b string
---@return boolean
local function sort_feature_members(a, b)
    local a_dep = string.sub(a, 1, 4) == "dep:"
    local b_dep = string.sub(b, 1, 4) == "dep:"
    if a_dep == b_dep then
        return a < b
    elseif a_dep then
        return false
    else -- if b_dep then
        return true
    end
end

---@param index_json_str string
---@param meta_json table<string,any>
---@return ApiCrate?
function M.parse_crate(index_json_str, meta_json)
    local lines = vim.split(index_json_str, '\n', { trimempty = true })

    -- parse versions from sparse index file
    ---@type table<string,ApiVersion>
    local versions = {}
    for _, line in ipairs(lines) do
        local json = M.parse_json(line)
        assert(json.vers ~= nil)

        ---@type ApiVersion
        local version = {
            num = json.vers,
            parsed = semver.parse_version(json.vers),
            yanked = json.yanked,
            features = ApiFeatures.new({}),
            deps = {},
        }

        ---@diagnostic disable-next-line: no-unknown
        for _, d in ipairs(json.deps) do
            if d.name then
                ---@type ApiDependency
                local dependency = {
                    name = d.name,
                    package = d.package,
                    opt = d.optional or false,
                    kind = DEPENDENCY_KIND_MAP[d.kind],
                    vers = {
                        text = d.req,
                        reqs = semver.parse_requirements(d.req),
                    },
                }
                table.insert(version.deps, dependency)
            end
        end

        local features2 = json.features2 or {}

        ---@param name string
        ---@param members string[]
        for name, members in pairs(json.features) do
            for i, m in ipairs(members) do
                if json.features[m] or features2[m] then
                    goto continue
                end

                -- enforce explicit `dep:<crate_name>` syntax
                for _, d in ipairs(version.deps) do
                    if d.name == m then
                        members[i] = "dep:" .. m
                        break
                    end
                end

                ::continue::
            end

            table.sort(members, sort_feature_members)

            version.features:insert({
                name = name,
                members = members,
            })
        end

        ---@param name string
        ---@param members string[]
        for name, members in pairs(features2) do
            table.sort(members, sort_feature_members)

            version.features:insert({
                name = name,
                members = members,
            })
        end

        -- sort features
        table.sort(version.features.list, sort_features)

        -- add missing default feature
        if not version.features.map["default"] then
            local feature = {
                name = "default",
                members = {},
            }
            table.insert(version.features.list, feature)
            version.features.map["default"] = feature
        end

        -- add optional dependencies as features
        for _, d in ipairs(version.deps) do
            if d.opt then
                version.features:insert({
                    name = "dep:" .. d.name,
                    members = {},
                    dep = true,
                })
            end
        end

        versions[version.num] = version
    end

    -- parse remaining metadata from api data
    ---@type table<string,any>
    local c = meta_json.crate
    ---@type ApiCrate
    local crate = {
        name = c.id,
        description = assert(c.description),
        created = assert(DateTime.parse_rfc_3339(c.created_at)),
        updated = assert(DateTime.parse_rfc_3339(c.updated_at)),
        downloads = assert(c.downloads),
        homepage = c.homepage,
        documentation = c.documentation,
        repository = c.repository,
        categories = {},
        keywords = {},
        versions = {},
    }

    ---@diagnostic disable-next-line: no-unknown
    for _, ct_id in ipairs(c.categories) do
        ---@diagnostic disable-next-line: no-unknown
        for _, ct in ipairs(meta_json.categories) do
            if ct.id == ct_id then
                table.insert(crate.categories, ct.category)
            end
        end
    end

    ---@diagnostic disable-next-line: no-unknown
    for _, kw_id in ipairs(c.keywords) do
        ---@diagnostic disable-next-line: no-unknown
        for _, kw in ipairs(meta_json.keywords) do
            if kw.id == kw_id then
                table.insert(crate.keywords, kw.keyword)
            end
        end
    end

    ---@diagnostic disable-next-line: no-unknown
    for _, v in ipairs(meta_json.versions) do
        local version = assert(versions[v.num])
        version.created = assert(DateTime.parse_rfc_3339(v.created_at))
        table.insert(crate.versions, version)
    end
    -- sort versions
    table.sort(crate.versions, function(a, b)
        return semver.matches_requirement(a.parsed, {
            cond = types.Cond.GT,
            vers = b.parsed,
        })
    end)

    return crate
end

---@param name string
---@param callbacks fun(crate: ApiCrate?, cancelled: boolean)[]
local function fetch_crate(name, callbacks)
    local existing = M.crate_jobs[name]
    if existing then
        vim.list_extend(existing.callbacks, callbacks)
        return
    end

    if M.num_requests >= state.cfg.max_parallel_requests then
        enqueue_crate_job(name, callbacks)
        return
    end

    local called = false
    ---@type string?
    local index_json_str = nil
    ---@type table<string,any>?
    local meta_json = nil

    ---@param cancelled boolean
    local function parse(cancelled)
        if called then
            return
        end

        if cancelled then
            for _, c in ipairs(callbacks) do
                c(nil, true)
            end
            called = true
            return
        end

        if not (index_json_str and meta_json) then
            return
        end

        ---@type boolean, ApiCrate?
        local ok, crate = pcall(M.parse_crate, index_json_str, meta_json)
        crate = (ok and crate) or nil

        for _, c in ipairs(callbacks) do
            c(crate, cancelled)
        end
        called = true

        M.crate_jobs[name] = nil
        M.num_requests = M.num_requests - 2

        M.run_queued_jobs()
    end

    ---@type { [1]: Job, [2]: Job }
    local jobs = {}

    local refetch = false
    ---@param id string
    local function fetch_index(id)
        ---@type string
        local url
        if #id == 1 then
            url = string.format("%s/1/%s", SPARSE_INDEX_ENDPOINT, id)
        elseif #id == 2 then
            url = string.format("%s/2/%s", SPARSE_INDEX_ENDPOINT, id)
        elseif #id == 3 then
            url = string.format("%s/3/%s/%s", SPARSE_INDEX_ENDPOINT, string.sub(id, 1, 1), id)
        else
            url = string.format("%s/%s/%s/%s", SPARSE_INDEX_ENDPOINT, string.sub(id, 1, 2), string.sub(id, 3, 4),
                id)
        end

        jobs[1] = start_job(url, function(json_str, cancelled)
            if refetch and name == id then
                return
            end

            index_json_str = json_str
            parse(cancelled)
        end)
    end
    fetch_index(name)

    do
        ---@type string
        local url = string.format("%s/crates/%s", API_ENDPOINT, name)

        jobs[2] = start_job(url, function(json_str, cancelled)
            if cancelled then
                parse(cancelled)
                return
            end

            -- the crates.io api is case and hyphen/underscore insensitive, but the sparse index
            -- requires the exact crate name. If the name doesn't match refetch the index with the
            -- exact name.
            local ok, json = pcall(M.parse_json, json_str)
            meta_json = (ok and json) or nil
            if ok and json.crate and json.crate.id ~= name then
                refetch = true
                kill_job(jobs[1])
                fetch_index(json.crate.id)
                return
            end

            parse(cancelled)
        end)
    end

    if jobs[1] and jobs[2] then
        M.num_requests = M.num_requests + 2
        M.crate_jobs[name] = {
            jobs = jobs,
            callbacks = callbacks,
        }
    else
        for _, c in ipairs(callbacks) do
            c(nil, false)
        end
    end
end

---@param name string
---@return ApiCrate?, boolean
function M.fetch_crate(name)
    ---@param resolve fun(crate: ApiCrate?, cancelled: boolean)
    return coroutine.yield(function(resolve)
        fetch_crate(name, { resolve })
    end)
end

---@param name string
---@return boolean
function M.is_fetching_crate(name)
    return M.crate_jobs[name] ~= nil
end

---@param name string
---@return boolean
function M.is_fetching_search(name)
    return M.search_jobs[name] ~= nil
end

---@param name string
---@param callback fun(crate: ApiCrate?, cancelled: boolean)
local function add_crate_callback(name, callback)
    table.insert(
        M.crate_jobs[name].callbacks,
        callback
    )
end

---@param name string
---@return ApiCrate?, boolean
function M.await_crate(name)
    ---@param resolve fun(crate: ApiCrate?, cancelled: boolean)
    return coroutine.yield(function(resolve)
        add_crate_callback(name, resolve)
    end)
end

---@param name string
---@param callback fun(deps: ApiCrateSummary[]?, cancelled: boolean)
local function add_search_callback(name, callback)
    table.insert(
        M.search_jobs[name].callbacks,
        callback
    )
end

---@param name string
---@return ApiCrateSummary[]?, boolean
function M.await_search(name)
    ---@param resolve fun(crate: ApiCrateSummary[]?, cancelled: boolean)
    return coroutine.yield(function(resolve)
        add_search_callback(name, resolve)
    end)
end

function M.run_queued_jobs()
    -- Prioritise crate searches
    if #M.search_queue > 0 then
        local job = table.remove(M.search_queue, 1)
        fetch_search(job.name, job.search_callbacks)
        return
    end

    if #M.crate_queue == 0 then
        return
    end

    local job = table.remove(M.crate_queue, 1)
    fetch_crate(job.name, job.callbacks)
end

function M.cancel_jobs()
    for _, r in pairs(M.crate_jobs) do
        kill_job(r.jobs[1])
        kill_job(r.jobs[2])
    end
    for _, r in pairs(M.search_jobs) do
        kill_job(r.job)
    end

    M.crate_jobs = {}
    M.search_jobs = {}
end

function M.cancel_search_jobs()
    for _, r in pairs(M.search_jobs) do
        kill_job(r.job)
    end
    M.search_jobs = {}
end

return M
