#!/bin/sh
_=[[
exec lua "$0" "$@"
]]

local doc_file = "doc/crates.txt"
local config = require('lua.crates.config')

local function gen_doc()
    -- config
    for k,v in pairs(config.schema) do
       
    end
end

gen_doc()
