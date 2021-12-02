#!/bin/sh
_=[[
exec lua "$0" "$@"
]]

local inspect = require("inspect")
local config = require('lua.crates.config')
local doc_file = "doc/crates.txt"

local function join_path(path, component)
    local p = {}
    for i,c in ipairs(path) do
        p[i] = c
    end
    table.insert(p, component)
    return p
end

local function gen_config_doc(lines, path, schema)
    for k,s in pairs(schema) do
        local p = join_path(path, k)
        local key = table.concat(p, ".")
        local doc_key = string.format("*crates-config-%s*", table.concat(p, "-"))

        if string.len(key) + string.len(doc_key) < 78 then
            table.insert(lines, string.format("%-31s %46s", key, doc_key))
        else
            table.insert(lines, string.format("%78s", doc_key))
            table.insert(lines, key)
        end

        if s.deprecated then
            if s.deprecated.new_field then
                local nf = table.concat(s.deprecated.new_field, ".")
                table.insert(lines, string.format("    DEPRECATED: please use %s", nf))
            else
                table.insert(lines, "    DEPRECATED")
            end
            table.insert(lines, "")
        end

        if s.type == "section" then
            table.insert(lines, "    Type: `section`")
            table.insert(lines, "")
        else
            local t = s.type
            if type(t) == "table" then
                t = table.concat(t, " or ")
            end
            local d = inspect(s.default)
            table.insert(lines, string.format("    Type: `%s`, Default: `%s`", t, d))
            table.insert(lines, "")
        end

        local leading_ws = s.description:match("^%s*()") - 1
        for l in s.description:gmatch("\n?([^\n]*)\n?") do
            local line = l:gsub("%s+$", ""):gsub("^" .. string.rep(" ", leading_ws), "    ")
            table.insert(lines, line)
        end

        table.insert(lines, "")

        if s.type == "section" then
            gen_config_doc(lines, p, s.fields)
        end
    end
end

local function gen_doc()
    local lines = {}
    gen_config_doc(lines, {}, config.schema)

    print(table.concat(lines, "\n"))
end

gen_doc()
