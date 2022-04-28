local record State
    cfg: Config
    vers_cache: {string:{Version}}
    crate_cache: {integer:{string:toml.Crate}}
    info_cache: {integer:{string:CrateInfo}}
    diagnostic_cache: {integer:{Diagnostic}}
    visible: boolean
end

local config = require("crates.config")
local Config = config.Config
local toml = require("crates.toml")
local types = require("crates.types")
local CrateInfo = types.CrateInfo
local Diagnostic = types.Diagnostic
local Version = types.Version

State.cfg = {}
State.vers_cache = {}
State.crate_cache = {}
State.info_cache = {}
State.diagnostic_cache = {}
State.visible = true

return State
