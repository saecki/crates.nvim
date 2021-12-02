#!/bin/sh
_=[[
exec lua "$0" "$@"
]]

local inspect = require("inspect")
local config = require('lua.crates.config')
local doc_file = "doc/crates.txt"
local doc_file_template = "scripts/crates.txt.in"

local function read_to_string(path)
    local file = io.open(path, "r")
    local text = file:read("*a")
    file:close()
    return text
end

local function write_to_path(path, str)
    local file = io.open(path, "w")
    file:write(str)
    file:close()
end

local function join_path(path, component)
    local p = {}
    for i,c in ipairs(path) do
        p[i] = c
    end
    table.insert(p, component)
    return p
end

local function gen_config_doc(lines, path, schema)
    for _,s in ipairs(schema) do
        local k = s.name
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
            table.insert(lines, "    DEPRECATED")
            if s.deprecated.new_field then
                local nf = "crates-config-" .. table.concat(s.deprecated.new_field, "-")
                table.insert(lines, "")
                table.insert(lines, string.format("    Please use %s instead.", nf))
            end
            table.insert(lines, "")
        else
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

            local description = s.description:gsub("^    ", ""):gsub("\n    ", "\n")
            table.insert(lines, description)
            table.insert(lines, "")
        end

        if s.type == "section" then
            gen_config_doc(lines, p, s.fields)
        end
    end
end

local function gen_doc()
    local input = read_to_string(doc_file_template)

    local func_lines = {
        "==============================================================================",
        "FUNCTIONS                                                   *crates-functions*",
        "",
        "TODO",
        "\n",
    }
    local func_text = table.concat(func_lines, "\n")

    local config_lines = {
        "==============================================================================",
        "CONFIGURATION                                                  *crates-config*",
        "",
    }
    gen_config_doc(config_lines, {}, config.schema)
    local config_text = table.concat(config_lines, "\n")

    local doc = input .. func_text .. config_text
    write_to_path(doc_file, doc)
end

gen_doc()
