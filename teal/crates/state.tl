local record State
    cfg: Config
    vers_cache: {string:{Version}}
    crate_cache: {integer:{string:Crate}}
    info_cache: {integer:{string:CrateInfo}}
    visible: boolean
end

local config = require("crates.config")
local Config = config.Config
local toml = require("crates.toml")
local Crate = toml.Crate
local types = require("crates.types")
local CrateInfo = types.CrateInfo
local Version = types.Version

State.cfg = {}
State.vers_cache = {}
State.crate_cache = {}
State.info_cache = {}
State.visible = true

return State
