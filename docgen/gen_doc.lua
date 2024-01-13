#!/bin/sh
_=[[
exec lua "$0" "$@"
]]

local inspect = require("inspect")
local config = require("lua.crates.config")
local highlight = require("lua.crates.highlight")
local version = "unstable"

local function gen_from_shared_file(lines, indent, filename)
    local infile = io.open("docgen/shared/" .. filename, "r")
    for l in infile:lines("*l") do
        l = string.rep("    ", indent) .. l
        l = l:gsub("%s+$", "")
        table.insert(lines, l)
    end
end

local function format_markdown_refs(line)
    line = line:gsub("`f#([^`]+)`", "`%1`")
    line = line:gsub("`p#([^`]+)`", "`%1`")
    line = line:gsub("`c#([^`]+)`", "`%1`")
    return line
end

local function gen_markdown_functions(lines)
    local file = io.open("teal/crates/init.tl", "r")
    for l in file:lines("*l") do
        if l == "end" then
            break
        end
        if l ~= "" then
            local pat = "^%s*([^:]+):%s*function%(([^%)]*)%)(.*)$"
            local name, params, ret_type = l:match(pat)
            if name and params and ret_type then
                local func_text = string.format('require("crates").%s(%s)%s', name, params, ret_type)
                table.insert(lines, func_text)
            else
                local doc = l:match("^%s*%-%-%s*(.*)$")
                if doc then
                    local fmt = format_markdown_refs(doc)
                    table.insert(lines, "-- " .. fmt)
                end
            end
        else
            table.insert(lines, "")
        end
    end
    file:close()
end

local function format_vimdoc_params(params)
    local text = {}
    for p, t in params:gmatch("[,]?([^:]+):%s*([^,]+)[,]?") do
        local fmt = string.format("{%s}: `%s`", p, t)
        table.insert(text, fmt)
    end
    return table.concat(text, ", ")
end

local function format_vimdoc_ret_type(return_type)
    local type = return_type:match("^%s*:%s*(.+)%s*$")
    if type then
        return string.format(": `%s`", type)
    else
        return ""
    end
end

local function format_vimdoc_refs(line)
    line = line:gsub("`f#([^`]+)`", "`%1`")
    line = line:gsub("`p#([^`]+)`", "{%1}")
    local os, opt, oe = line:match("()`c#([^`]+)`()")
    if os and opt and oe then
        local pat = "%s|crates-config-%s|%s"
        local before = line:sub(0, os - 1)
        local cfg_opt = opt:gsub("%.", "-")
        local after = line:sub(oe, #line)
        line = string.format(pat, before, cfg_opt, after)
    end
    return line
end

local function gen_vimdoc_functions(lines)
    local func_doc = {}

    local file = io.open("teal/crates/init.tl", "r")
    for l in file:lines("*l") do
        if l == "end" then
            break
        end
        if l ~= "" then
            local pat = "^%s*([^:]+):%s*function%(([^%)]*)%)(.*)$"
            local name, params, ret_type = l:match(pat)
            if name and params and ret_type then
                local doc_params = format_vimdoc_params(params)
                local doc_ret_type = format_vimdoc_ret_type(ret_type)
                local doc_title = string.format("%s(%s)%s", name, doc_params, doc_ret_type)
                local doc_key = string.format("*crates.%s()*", name)

                local len = string.len(doc_title) + string.len(doc_key)
                if len < 78 then
                    local txt = doc_title .. string.rep(" ", 78 - len) .. doc_key
                    table.insert(lines, txt)
                else
                    table.insert(lines, string.format("%78s", doc_key))
                    table.insert(lines, doc_title)
                end

                for _, dl in ipairs(func_doc) do
                    local fmt = format_vimdoc_refs(dl)
                    table.insert(lines, "    " .. fmt)
                end
                table.insert(lines, "")
                table.insert(lines, "")

                func_doc = {}
            else
                local doc = l:match("^%s*%-%-%s*(.*)$")
                if doc then
                    table.insert(func_doc, doc)
                end
            end
        end
    end
    file:close()
end

local function gen_vimdoc_subcommands(lines)
    local file = io.open("teal/crates/command.tl", "r")
    local line_iter = file:lines("*l")
    for l in line_iter do
        if l:match("^local sub_commands:") then
            break
        end
    end

    for l in line_iter do
        if l == "}" then
            break
        end
        if l ~= "" then
            local pat = "^%s*{%s*\"([^\"]+)\"%s*,%s*[^%s]+%s*},$"
            local name = l:match(pat)
            if name then
                local doc_ref = string.format("    - |crates.%s()|", name)
                table.insert(lines, doc_ref)
            end
        end
    end
    file:close()
end

local function gen_vimdoc_highlights(lines)
    for _, value in ipairs(highlight.highlights) do
        local name = value[1]
        local hl = value[2]
        local doc_title = name
        local doc_key = string.format("*crates-hl-%s*", name)

        local len = string.len(doc_title) + string.len(doc_key)
        if len < 78 then
            local txt = doc_title .. string.rep(" ", 78 - len) .. doc_key
            table.insert(lines, txt)
        else
            table.insert(lines, string.format("%78s", doc_key))
            table.insert(lines, doc_title)
        end

        if hl.link then
            table.insert(lines, string.format("    Default: links to |%s|", hl.link))
            table.insert(lines, "")
        else
            local colors = ""
            local function append_if_not_nil(name, value)
                if value then
                    if colors ~= "" then
                        colors = colors .. " "
                    end
                    colors = colors .. string.format("%s=%s", name, value)
                end
            end

            append_if_not_nil("ctermfg", hl.ctermfg)
            append_if_not_nil("ctermbg", hl.ctermbg)
            append_if_not_nil("fg", hl.fg)
            append_if_not_nil("bg", hl.bg)

            table.insert(lines, string.format("    Default: `%s`", colors))
            table.insert(lines, "")
        end
    end
end

local function join_path(path, component)
    local p = {}
    for i, c in ipairs(path) do
        p[i] = c
    end
    table.insert(p, component)
    return p
end

local function gen_vimdoc_config(lines, path, schema)
    for _, s in ipairs(schema) do
        if s.hidden then
            goto continue
        end

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
                table.insert(lines, string.format("    Please use |%s| instead.", nf))
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
                local d = s.default_text
                if not d then
                    d = inspect(s.default)
                end
                table.insert(lines, string.format("    Type: `%s`, Default: `%s`", t, d))
                table.insert(lines, "")
            end

            local description = s.description:gsub("^    ", ""):gsub("\n    ", "\n")
            table.insert(lines, description)
            table.insert(lines, "")
        end

        if s.type == "section" then
            gen_vimdoc_config(lines, p, s.fields)
        end

        ::continue::
    end
end

local function gen_def_config(lines, indent, path, schema)
    local function insert_indent(str)
        local l = string.rep("    ", #path + indent) .. str
        table.insert(lines, l)
    end

    for _, s in ipairs(schema) do
        if not s.hidden and not s.deprecated then
            local name = s.name

            if s.type == "section" then
                local p = join_path(path, name)
                insert_indent(name .. " = {")
                gen_def_config(lines, indent, p, s.fields)
                insert_indent("},")
            else
                local d = s.default_text or inspect(s.default)
                insert_indent(string.format("%s = %s,", name, d))
            end
        end
    end
end

local function parse_placeholder(l)
    local preceeding_spaces, placeholder = l:match("^%s*()<SHARED%:([a-zA-Z0-9_%.]+)>$")
    if placeholder then
        local spaces = preceeding_spaces - 1
        if spaces % 4 ~= 0 then
            error(string.format("4 space indent is enforced, but found %s spaced in line:\n%s", spaces, l))
        end
        local indent = spaces / 4
        return placeholder, indent
    end
end

local function gen_vim_doc()
    local lines = {}

    local infile = io.open("docgen/templates/crates.txt.in", "r")
    for l in infile:lines("*l") do
        local ph, indent = parse_placeholder(l)
        if ph then
            if ph == "DEFAULT_CONFIGURATION" then
                gen_def_config(lines, 2, {}, config.schema)
            elseif ph == "FUNCTIONS" then
                gen_vimdoc_functions(lines)
            elseif ph == "SUBCOMMANDS" then
                gen_vimdoc_subcommands(lines)
            elseif ph == "CONFIGURATION" then
                gen_vimdoc_config(lines, {}, config.schema)
            elseif ph == "HIGHLIGHTS" then
                gen_vimdoc_highlights(lines)
            else
                gen_from_shared_file(lines, indent, ph)
            end
        else
            l = l:gsub("<VERSION>", version)
            table.insert(lines, l)
        end
    end
    infile:close()

    local doc = table.concat(lines, "\n")
    local outfile = io.open("doc/crates.txt", "w")
    outfile:write(doc)
    outfile:close()
end

local function gen_markdown(inpath, outpath)
    local lines = {}

    local infile = io.open(inpath, "r")
    for l in infile:lines("*l") do
        local ph, indent = parse_placeholder(l)
        if ph then
            if ph == "DEFAULT_CONFIGURATION" then
                gen_def_config(lines, 1, {}, config.schema)
            elseif ph == "FUNCTIONS" then
                gen_markdown_functions(lines)
            else
                gen_from_shared_file(lines, indent, ph)
            end
        else
            l = l:gsub("<VERSION>", version)
            table.insert(lines, l)
        end
    end
    infile:close()

    local doc = table.concat(lines, "\n")
    local outfile = io.open(outpath, "w")
    outfile:write(doc)
    outfile:close()
end

local function gen_docs()
    gen_vim_doc()
    gen_markdown("docgen/templates/README.md.in", "README.md")
    gen_markdown("docgen/templates/documentation.md.in", "docgen/wiki/Unstable-documentation.md")
end

gen_docs()
