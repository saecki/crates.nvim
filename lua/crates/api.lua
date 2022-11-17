local M = {CrateJob = {}, VersJob = {}, DepsJob = {}, }




















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
M.vers_jobs = {}
M.deps_jobs = {}


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
   }

   if json.categories then
      for _, ct_id in ipairs(c.categories) do
         for _, ct in ipairs(json.categories) do
            if ct.id == ct_id then
               table.insert(crate.categories, ct.category)
            end
         end
      end
   end

   if json.keywords then
      for _, kw_id in ipairs(c.keywords) do
         for _, kw in ipairs(json.keywords) do
            if kw.id == kw_id then
               table.insert(crate.keywords, kw.keyword)
            end
         end
      end
   end

   return crate
end

local function fetch_crate(name, callback)
   if M.crate_jobs[name] then
      return
   end

   local callbacks = { callback }
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
   end

   local job = request_job(url, on_exit)
   M.crate_jobs[name] = {
      job = job,
      callbacks = callbacks,
   }
   job:start()
end

function M.fetch_crate(name)
   return coroutine.yield(function(resolve)
      fetch_crate(name, resolve)
   end)
end


function M.parse_vers(json_str)
   local json = parse_json(json_str)
   if not (json and json.versions) then
      return
   end

   local versions = {}
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
            table.insert(version.features, {
               name = n,
               members = m,
            })
         end


         for _, f in ipairs(version.features) do
            for _, m in ipairs(f.members) do
               if not version.features:get_feat(m) then
                  table.insert(version.features, {
                     name = m,
                     members = {},
                  })
               end
            end
         end


         version.features:sort()


         if not version.features[1] or not (version.features[1].name == "default") then
            for i = #version.features, 1, -1 do
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

local function fetch_vers(name, callback)
   if M.vers_jobs[name] then
      return
   end

   local callbacks = { callback }
   local url = string.format("%s/crates/%s/versions", ENDPOINT, name)

   local function on_exit(j, code, signal)
      local cancelled = signal ~= 0

      local json = nil
      if code == 0 then
         json = table.concat(j:result(), "\n")
      end

      local versions = nil
      if not cancelled then
         versions = M.parse_vers(json)
      end
      for _, c in ipairs(callbacks) do
         c(versions, cancelled)
      end

      M.vers_jobs[name] = nil
   end

   local job = request_job(url, on_exit)
   M.vers_jobs[name] = {
      job = job,
      callbacks = callbacks,
   }
   job:start()
end

function M.fetch_vers(name)
   return coroutine.yield(function(resolve)
      fetch_vers(name, resolve)
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

local function fetch_deps(name, version, callback)
   local jobname = name .. ":" .. version
   if M.deps_jobs[jobname] then
      return
   end

   local callbacks = { callback }
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

      M.deps_jobs[jobname] = nil
   end

   local job = request_job(url, on_exit)
   M.deps_jobs[jobname] = {
      job = job,
      callbacks = callbacks,
   }
   job:start()
end

function M.fetch_deps(name, version)
   return coroutine.yield(function(resolve)
      fetch_deps(name, version, resolve)
   end)
end

function M.is_fetching_vers(name)
   return M.vers_jobs[name] ~= nil
end

function M.is_fetching_deps(name, version)
   return M.deps_jobs[name .. ":" .. version] ~= nil
end

local function add_vers_callback(name, callback)
   table.insert(
   M.vers_jobs[name].callbacks,
   callback)

end

function M.await_vers(name)
   return coroutine.yield(function(resolve)
      add_vers_callback(name, resolve)
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

function M.cancel_jobs()
   for _, r in pairs(M.vers_jobs) do
      r.job:shutdown(1, 1)
   end
   for _, r in pairs(M.deps_jobs) do
      r.job:shutdown(1, 1)
   end
   M.vers_jobs = {}
   M.deps_jobs = {}
end

return M
