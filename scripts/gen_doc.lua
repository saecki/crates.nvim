#!/bin/sh
_=[[
exec lua "$0" "$@"
]]

local inspect = require("inspect")
local config = require('lua.crates.config')

local function format_params(params)
    local text = {}
    for p,t in params:gmatch("[,]?([^:]+):%s*([^,]+)[,]?") do
        local fmt = string.format("{%s}: `%s`", p, t)
        table.insert(text, fmt)
    end
    return table.concat(text, ", ")
end

local function gen_func_doc(lines)
    local func_doc = {}

    local file = io.open("teal/crates.tl", "r")
    for l in file:lines("*l") do
        if l == "end" then
            break
        end
        if l ~= "" then
            local pat = "^%s*([^:]+):%s*function%(([^%)]*)%)$"
            local name, params = l:match(pat)
            if name and params then
                local doc_params = format_params(params)
                local doc_title = string.format("%s(%s)", name, doc_params)
                local doc_key = string.format("*crates-functions-%s*", name)

                local len = string.len(doc_title) + string.len(doc_key)
                if len < 78 then
                    local txt = doc_title .. string.rep(" ", 78 - len) .. doc_key
                    table.insert(lines, txt)
                else
                    table.insert(lines, string.format("%78s", doc_key))
                    table.insert(lines, doc_title)
                end

                for _,dl in ipairs(func_doc) do
                    table.insert(lines, "    " .. dl)
                end
                table.insert(lines, "")
                table.insert(lines, "")

                func_doc = {}
            else
                local doc = l:match("^%s*%-%-(.*)$")
                if doc then
                    table.insert(func_doc, doc)
                end
            end
        end
    end
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

local function gen_def_config_doc(lines, indent, path, schema)
    local function insert_indent(str)
        local l = string.rep("    ", #path + indent) .. str
        table.insert(lines, l)
    end

    for _,s in ipairs(schema) do
        local name = s.name

        if s.type == "section" then
            local p = join_path(path, name)
            insert_indent(name .. " = {")
            gen_def_config_doc(lines, indent, p, s.fields)
            insert_indent("}")
        else
            local d = inspect(s.default)
            insert_indent(name .. " = " .. d)
        end
    end
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
    local lines = {}

    local infile = io.open("scripts/crates.txt.in", "r")
    for l in infile:lines("*l") do
        if l == "<DEFAULT_CONFIGURATION>" then
            gen_def_config_doc(lines, 2, {}, config.schema)
        elseif l == "<FUNCTIONS>" then
            gen_func_doc(lines)
        elseif l == "<CONFIGURATION>" then
            gen_config_doc(lines, {}, config.schema)
        else
            table.insert(lines, l)
        end
    end
    infile:close()

    local doc = table.concat(lines, "\n")
    local outfile = io.open("doc/crates.txt", "w")
    outfile:write(doc)
    outfile:close()
end

gen_doc()
