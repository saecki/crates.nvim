local M = {Version = {}, Features = {}, Feature = {}, Dependency = {}, }
































local Version = M.Version
local Features = M.Features
local Feature = M.Feature
local Dependency = M.Dependency
local Job = require('plenary.job')
local semver = require('crates.semver')
local SemVer = semver.SemVer
local DateTime = require('crates.time').DateTime

local endpoint = "https://crates.io/api/v1"
local useragent = vim.fn.shellescape("crates.nvim (https://github.com/saecki/crates.nvim)")

M.running_jobs = {}


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

function M.fetch_crate_versions(name, callback)
   if M.running_jobs[name] then
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


               table.sort(version.features, function(a, b)
                  if a.name == "default" then
                     return true
                  elseif b.name == "default" then
                     return false
                  else
                     return a.name < b.name
                  end
               end)


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

      callback(versions)
   end

   local function on_exit(j, code, signal)
      if signal ~= 0 then return end

      if code == 0 then
         resp = table.concat(j:result(), "\n")
      end

      parse_json()

      M.running_jobs[name] = nil
   end

   local j = Job:new({
      command = "curl",
      args = { "-sLA", useragent, url },
      on_exit = vim.schedule_wrap(on_exit),
   })

   M.running_jobs[name] = j

   j:start()
end

function M.fetch_crate_deps(name, version, callback)
   local jobname = name .. ":" .. version
   if M.running_jobs[jobname] then
      return
   end

   local url = string.format("%s/crates/%s/%s/dependencies", endpoint, name, version)
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

      local dependencies = {}
      if data and type(data) == "table" and data.dependencies then
         for _, d in ipairs(data.dependencies) do
            if d.name then
               table.insert(dependencies, {
                  name = d.name,
                  opt = d.optional,
                  kind = d.kind,
               })
            end
         end
      end

      callback(dependencies)
   end

   local function on_exit(j, code, signal)
      if signal ~= 0 then return end

      if code == 0 then
         resp = table.concat(j:result(), "\n")
      end

      parse_json()

      M.running_jobs[jobname] = nil
   end

   local j = Job:new({
      command = "curl",
      args = { "-sLA", useragent, url },
      on_exit = vim.schedule_wrap(on_exit),
   })

   M.running_jobs[jobname] = j

   j:start()
end

function M.cancel_jobs()
   for _, j in pairs(M.running_jobs) do
      j:shutdown(1, 1)
   end
   M.running_jobs = {}
end

return M
