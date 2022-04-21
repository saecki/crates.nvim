local M = {VersJob = {}, DepsJob = {}, Version = {}, Features = {}, Feature = {}, Dependency = {Vers = {}, }, }


















































local Dependency = M.Dependency
local Feature = M.Feature
local Features = M.Features
local Version = M.Version
local semver = require("crates.semver")
local Requirement = semver.Requirement
local SemVer = semver.SemVer
local time = require("crates.time")
local DateTime = time.DateTime
local Job = require("plenary.job")

local endpoint = "https://crates.io/api/v1"
local useragent = vim.fn.shellescape("crates.nvim (https://github.com/saecki/crates.nvim)")
local json_decode_opts = { luanil = { object = true, array = true } }

M.vers_jobs = {}
M.deps_jobs = {}


function Features.new(obj)
   return setmetatable(obj, { __index = Features })
end

function Features:get_feat(name)
   for i, f in ipairs(self) do
      if f.name == name then
         return f, i
      end
   end

   return nil, nil
end

function Features:sort()
   table.sort(self, function(a, b)
      if a.name == "default" then
         return true
      elseif b.name == "default" then
         return false
      else
         return a.name < b.name
      end
   end)
end


local function parse_versions(json)
   if not json then
      return nil
   end

   local success, data = pcall(vim.json.decode, json, json_decode_opts)
   if not success then
      data = nil
   end

   local versions = {}
   if data and type(data) == "table" and data.versions then
      for _, v in ipairs(data.versions) do
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
   end

   return versions
end

function M.fetch_crate_versions(name, callback)
   if M.vers_jobs[name] then
      return
   end

   local callbacks = { callback }
   local url = string.format("%s/crates/%s/versions", endpoint, name)

   local function on_exit(j, code, signal)
      local cancelled = signal ~= 0

      local json = nil
      if code == 0 then
         json = table.concat(j:result(), "\n")
      end

      local versions = nil
      if not cancelled then
         versions = parse_versions(json)
      end
      for _, c in ipairs(callbacks) do
         c(versions, cancelled)
      end

      M.vers_jobs[name] = nil
   end

   local j = Job:new({
      command = "curl",
      args = { "-sLA", useragent, url },
      on_exit = vim.schedule_wrap(on_exit),
   })

   M.vers_jobs[name] = {
      job = j,
      callbacks = callbacks,
   }

   j:start()
end

local function parse_deps(json)
   if not json then
      return nil
   end

   local success, data = pcall(vim.json.decode, json, json_decode_opts)
   if not success then
      data = nil
   end

   local dependencies = {}
   if data and type(data) == "table" and data.dependencies then
      for _, d in ipairs(data.dependencies) do
         if d.crate_id then
            table.insert(dependencies, {
               name = d.crate_id,
               opt = d.optional or false,
               kind = d.kind or "normal",
               vers = {
                  text = d.req,
                  reqs = semver.parse_requirements(d.req),
               },
            })
         end
      end
   end

   return dependencies
end

function M.fetch_crate_deps(name, version, callback)
   local jobname = name .. ":" .. version
   if M.deps_jobs[jobname] then
      return
   end

   local callbacks = { callback }
   local url = string.format("%s/crates/%s/%s/dependencies", endpoint, name, version)

   local function on_exit(j, code, signal)
      local cancelled = signal ~= 0

      local json = nil
      if code == 0 then
         json = table.concat(j:result(), "\n")
      end

      local deps = nil
      if not cancelled then
         deps = parse_deps(json)
      end
      for _, c in ipairs(callbacks) do
         c(deps, cancelled)
      end

      M.deps_jobs[jobname] = nil
   end

   local j = Job:new({
      command = "curl",
      args = { "-sLA", useragent, url },
      on_exit = vim.schedule_wrap(on_exit),
   })

   M.deps_jobs[jobname] = {
      job = j,
      callbacks = callbacks,
   }

   j:start()
end

function M.is_fetching_vers(name)
   return M.vers_jobs[name] ~= nil
end

function M.is_fetching_deps(name, version)
   return M.deps_jobs[name .. ":" .. version] ~= nil
end

function M.add_vers_callback(name, callback)
   table.insert(
   M.vers_jobs[name].callbacks,
   callback)

end

function M.await_vers(name)
   return coroutine.yield(function(resolve)
      M.add_vers_callback(name, resolve)
   end)
end

function M.add_deps_callback(name, version, callback)
   table.insert(
   M.deps_jobs[name .. ":" .. version].callbacks,
   callback)

end

function M.await_deps(name, version)
   return coroutine.yield(function(resolve)
      M.add_deps_callback(name, version, resolve)
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
