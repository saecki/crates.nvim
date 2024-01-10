local M = {CrateJob = {}, DepsJob = {}, QueuedJob = {}, }

































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
local USERAGENT = vim.fn.shellescape("crates.nvim (https://github.com/saecki/crates.nvim)")
local JSON_DECODE_OPTS = { luanil = { object = true, array = true } }

M.crate_jobs = {}
M.deps_jobs = {}
M.queued_jobs = {}
M.num_requests = 0


local function parse_json(json_str)
   if not json_str then
      return
   end

   local success, json = pcall(vim.json.decode, json_str, JSON_DECODE_OPTS)
   if not success then
      return
   end

   if json and type(json) == "table" then
      return json
   end
end

local function request_job(url, on_exit)
   return Job:new({
      command = "curl",
      args = { unpack(state.cfg.curl_args), "-A", USERAGENT, url },
      on_exit = vim.schedule_wrap(on_exit),
   })
end

local function enqueue_crate_job(name, callbacks)
   for _, j in ipairs(M.queued_jobs) do
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

local function enqueue_deps_job(name, version, callbacks)
   for _, j in ipairs(M.queued_jobs) do
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


function M.parse_crate(json_str)
   local json = parse_json(json_str)
   if not (json and json.crate) then
      return
   end

   local c = json.crate
   local crate = {
      name = c.id,
      description = c.description,
      created = DateTime.parse_rfc_3339(c.created_at),
      updated = DateTime.parse_rfc_3339(c.updated_at),
      downloads = c.downloads,
      homepage = c.homepage,
      documentation = c.documentation,
      repository = c.repository,
      categories = {},
      keywords = {},
      versions = {},
   }

   for _, ct_id in ipairs(c.categories) do
      for _, ct in ipairs(json.categories) do
         if ct.id == ct_id then
            table.insert(crate.categories, ct.category)
         end
      end
   end

   for _, kw_id in ipairs(c.keywords) do
      for _, kw in ipairs(json.keywords) do
         if kw.id == kw_id then
            table.insert(crate.keywords, kw.keyword)
         end
      end
   end

   for _, v in ipairs(json.versions) do
      if v.num then
         local version = {
            num = v.num,
            features = Features.new({}),
            yanked = v.yanked,
            parsed = semver.parse_version(v.num),
            created = DateTime.parse_rfc_3339(v.created_at),
         }

         for n, m in pairs(v.features) do
            table.sort(m)
            version.features:insert({
               name = n,
               members = m,
            })
         end


         for _, f in ipairs(version.features.list) do
            for _, m in ipairs(f.members) do

               if not string.find(m, "/") and not version.features:get_feat(m) then
                  version.features:insert({
                     name = m,
                     members = {},
                  })
               end
            end
         end


         version.features:sort()


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

   local url = string.format("%s/crates/%s", ENDPOINT, name)

   local function on_exit(j, code, signal)
      local cancelled = signal ~= 0

      local json = nil
      if code == 0 then
         json = table.concat(j:result(), "\n")
      end

      local crate = nil
      if not cancelled then
         crate = M.parse_crate(json)
      end
      for _, c in ipairs(callbacks) do
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

function M.fetch_crate(name)
   return coroutine.yield(function(resolve)
      fetch_crate(name, { resolve })
   end)
end


function M.parse_deps(json_str)
   local json = parse_json(json_str)
   if not (json and json.dependencies) then
      return
   end

   local dependencies = {}
   for _, d in ipairs(json.dependencies) do
      if d.crate_id then
         local dependency = {
            name = d.crate_id,
            opt = d.optional or false,
            kind = d.kind or "normal",
            vers = {
               text = d.req,
               reqs = semver.parse_requirements(d.req),
            },
         }
         table.insert(dependencies, dependency)
      end
   end

   return dependencies
end

local function fetch_deps(name, version, callbacks)
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

   local function on_exit(j, code, signal)
      local cancelled = signal ~= 0

      local json = nil
      if code == 0 then
         json = table.concat(j:result(), "\n")
      end

      local deps = nil
      if not cancelled then
         deps = M.parse_deps(json)
      end
      for _, c in ipairs(callbacks) do
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

function M.fetch_deps(name, version)
   return coroutine.yield(function(resolve)
      fetch_deps(name, version, { resolve })
   end)
end


function M.is_fetching_crate(name)
   return M.crate_jobs[name] ~= nil
end

function M.is_fetching_deps(name, version)
   return M.deps_jobs[name .. ":" .. version] ~= nil
end

local function add_crate_callback(name, callback)
   table.insert(
   M.crate_jobs[name].callbacks,
   callback)

end

function M.await_crate(name)
   return coroutine.yield(function(resolve)
      add_crate_callback(name, resolve)
   end)
end

local function add_deps_callback(name, version, callback)
   table.insert(
   M.deps_jobs[name .. ":" .. version].callbacks,
   callback)

end

function M.await_deps(name, version)
   return coroutine.yield(function(resolve)
      add_deps_callback(name, version, resolve)
   end)
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
   for _, r in pairs(M.crate_jobs) do
      r.job:shutdown(1, 1)
   end
   for _, r in pairs(M.deps_jobs) do
      r.job:shutdown(1, 1)
   end
   M.crate_jobs = {}
   M.deps_jobs = {}
end

return M
